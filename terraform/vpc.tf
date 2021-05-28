#
# VPC Resources
#  * VPC
#  * Subnets
#  * Internet Gateway
#  * Route Table
#

resource "aws_vpc" "eks" {
  cidr_block = var.vpc_cidr

  tags = map(
    "Name", "${var.cluster_name}-vpc",
    "kubernetes.io/cluster/${var.cluster_name}", "shared",
  )
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

# Public subnets to land loadbalancers/NAT/etc.
resource "aws_subnet" "public_eks" {
  count = var.subnet_count

  availability_zone       = data.aws_availability_zones.available.names[count.index]
  cidr_block              = cidrsubnet(var.public_cidr, ceil(log(2, var.subnet_count)), count.index)
  vpc_id                  = aws_vpc.eks.id
  map_public_ip_on_launch = true

  tags = map(
    "Name", "${var.cluster_name}-public-${count.index}",
    "kubernetes.io/cluster/${var.cluster_name}", "shared",
    "kubernetes.io/role/elb", "1",
  )
}

# eks subnets
resource "aws_subnet" "eks" {
  count = var.subnet_count

  availability_zone       = data.aws_availability_zones.available.names[count.index]
  cidr_block              = cidrsubnet(var.eks_cidr, ceil(log(2, var.subnet_count)), count.index)
  vpc_id                  = aws_vpc.eks.id
  map_public_ip_on_launch = false

  tags = map(
    "Name", "${var.cluster_name}-node-${count.index}",
    "kubernetes.io/cluster/${var.cluster_name}", "shared",
    "kubernetes.io/role/internal-elb", "1"
  )
}

resource "aws_internet_gateway" "eks" {
  vpc_id = aws_vpc.eks.id

  tags = {
    Name = var.cluster_name
  }
}

resource "aws_route_table" "public_eks" {
  count  = var.subnet_count
  vpc_id = aws_vpc.eks.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = data.aws_vpc_endpoint.networkfw[count.index].id
  }

  tags = {
    Name = "${var.cluster_name}-eks-${count.index}"
  }
}

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
  subnet_id     = aws_subnet.public_eks[count.index].id

  tags = {
    Name = "${var.cluster_name} NAT ${count.index}"
  }
}

resource "aws_route_table" "eks" {
  count = var.subnet_count

  vpc_id = aws_vpc.eks.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat[count.index].id
  }

  tags = {
    Name = "${var.cluster_name} route to NAT ${count.index}"
  }
}

resource "aws_route_table_association" "eks" {
  count = var.subnet_count

  subnet_id      = aws_subnet.eks[count.index].id
  route_table_id = aws_route_table.eks[count.index].id
}
