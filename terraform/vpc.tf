#
# VPC Resources
#  * VPC
#  * Subnets
#  * Internet Gateway
#  * Route Table
#

resource "aws_vpc" "eks" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = tomap({
    "Name"                                      = "${var.cluster_name}-vpc",
    "kubernetes.io/cluster/${var.cluster_name}" = "shared",
  })
}

# Public subnets to land NAT.
resource "aws_subnet" "nat" {
  count = var.subnet_count

  availability_zone       = data.aws_availability_zones.available.names[count.index]
  cidr_block              = cidrsubnet(var.nat_cidr, ceil(log(2, var.subnet_count)), count.index)
  vpc_id                  = aws_vpc.eks.id
  map_public_ip_on_launch = true

  tags = tomap({
    "Name" = "${var.cluster_name}-nat-${count.index}",
  })
}

# Public subnets to land loadbalancers/etc.
resource "aws_subnet" "public_eks" {
  count = var.subnet_count

  availability_zone       = data.aws_availability_zones.available.names[count.index]
  cidr_block              = cidrsubnet(var.public_cidr, ceil(log(2, var.subnet_count)), count.index)
  vpc_id                  = aws_vpc.eks.id
  map_public_ip_on_launch = true

  tags = tomap({
    "Name"                                      = "${var.cluster_name}-public-${count.index}",
    "kubernetes.io/cluster/${var.cluster_name}" = "shared",
    "kubernetes.io/role/elb"                    = "1",
  })
}

# eks subnets
resource "aws_subnet" "eks" {
  count = var.subnet_count

  availability_zone       = data.aws_availability_zones.available.names[count.index]
  cidr_block              = cidrsubnet(var.eks_cidr, ceil(log(2, var.subnet_count)), count.index)
  vpc_id                  = aws_vpc.eks.id
  map_public_ip_on_launch = false

  tags = tomap({
    "Name"                                      = "${var.cluster_name}-node-${count.index}",
    "kubernetes.io/cluster/${var.cluster_name}" = "shared",
    "kubernetes.io/role/internal-elb"           = "1"
  })
}

# db/service networks
resource "aws_subnet" "service" {
  count = var.subnet_count

  availability_zone       = data.aws_availability_zones.available.names[count.index]
  cidr_block              = cidrsubnet(var.service_cidr, ceil(log(2, var.subnet_count)), count.index)
  vpc_id                  = aws_vpc.eks.id
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.cluster_name}-service-${count.index}"
  }
}


# Internet Gateway
resource "aws_internet_gateway" "eks" {
  vpc_id = aws_vpc.eks.id

  tags = {
    Name = var.cluster_name
  }
}

# route traffic destined for the NAT gateways to the NAT endpoints from the IGW
resource "aws_route_table" "eks_igw" {
  vpc_id = aws_vpc.eks.id
  dynamic "route" {
    for_each = aws_subnet.nat.*.cidr_block
    content {
      cidr_block      = route.value
      vpc_endpoint_id = data.aws_vpc_endpoint.networkfw[route.key].id
    }
  }

  tags = {
    Name = "${var.cluster_name} routes back to NAT"
  }
}

# apply the IGW routes to the IGW
resource "aws_route_table_association" "eks_igw" {
  gateway_id     = aws_internet_gateway.eks.id
  route_table_id = aws_route_table.eks_igw.id
}

# the public subnet's default route is out through the IGW
resource "aws_route_table" "public_eks" {
  count  = var.subnet_count
  vpc_id = aws_vpc.eks.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.eks.id
  }

  tags = {
    Name = "${var.cluster_name}-public_eks-${count.index}"
  }
}

# apply the public subnet route table to the public subnet
resource "aws_route_table_association" "public_eks" {
  count = var.subnet_count

  subnet_id      = aws_subnet.public_eks[count.index].id
  route_table_id = aws_route_table.public_eks[count.index].id
}

resource "aws_eip" "nat_gateway" {
  count = var.subnet_count
  vpc   = true
}

resource "aws_nat_gateway" "nat" {
  count      = var.subnet_count
  depends_on = [aws_internet_gateway.eks]

  allocation_id = aws_eip.nat_gateway[count.index].id
  subnet_id     = aws_subnet.nat[count.index].id

  tags = {
    Name = "${var.cluster_name} NAT ${count.index}"
  }
}

resource "aws_route_table" "nat" {
  count = var.subnet_count

  vpc_id = aws_vpc.eks.id
  route {
    cidr_block      = "0.0.0.0/0"
    vpc_endpoint_id = data.aws_vpc_endpoint.networkfw[count.index].id
  }

  tags = {
    Name = "${var.cluster_name} NAT to igw ${count.index}"
  }
}

resource "aws_route_table_association" "nat" {
  count = var.subnet_count

  subnet_id      = aws_subnet.nat[count.index].id
  route_table_id = aws_route_table.nat[count.index].id
}

resource "aws_route_table" "eks" {
  count = var.subnet_count

  vpc_id = aws_vpc.eks.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat[count.index].id
  }

  tags = {
    Name = "${var.cluster_name} eks route to NAT ${count.index}"
  }
}

resource "aws_route_table_association" "eks" {
  count = var.subnet_count

  subnet_id      = aws_subnet.eks[count.index].id
  route_table_id = aws_route_table.eks[count.index].id
}

data "aws_vpc_endpoint_service" "sts" {
  service      = "sts"
  service_type = "Interface"
}

resource "aws_vpc_endpoint" "sts" {
  vpc_id              = aws_vpc.eks.id
  service_name        = data.aws_vpc_endpoint_service.sts.service_name
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  subnet_ids          = aws_subnet.service.*.id
  private_dns_enabled = true

  tags = {
    Name = "${var.cluster_name} sts"
  }
}

data "aws_vpc_endpoint_service" "email-smtp" {
  service      = "email-smtp"
  service_type = "Interface"
}

resource "aws_vpc_endpoint" "email-smtp" {
  vpc_id              = aws_vpc.eks.id
  service_name        = data.aws_vpc_endpoint_service.email-smtp.service_name
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  subnet_ids          = aws_subnet.service.*.id
  private_dns_enabled = true

  tags = {
    Name = "${var.cluster_name} email-smtp"
  }
}

resource "aws_security_group" "vpc_endpoints" {
  name        = "vpc_endpoints"
  description = "Allow eks to contact vpc endpoints"
  vpc_id      = aws_vpc.eks.id

  ingress {
    description     = "allow eks to contact vpc endpoints"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.eks-cluster.id, aws_eks_cluster.eks.vpc_config[0].cluster_security_group_id]
  }

  ingress {
    description     = "allow eks to contact smtp vpc endpoints"
    from_port       = 587
    to_port         = 587
    protocol        = "tcp"
    security_groups = [aws_security_group.eks-cluster.id, aws_eks_cluster.eks.vpc_config[0].cluster_security_group_id]
  }

  tags = {
    Name = "${var.cluster_name} vpc_endpoints"
  }
}
