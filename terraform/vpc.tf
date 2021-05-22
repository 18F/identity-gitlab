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

# have the db/service networks first because they probably won't grow
resource "aws_subnet" "service" {
  count = var.service_subnet_count

  availability_zone       = data.aws_availability_zones.available.names[count.index]
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  vpc_id                  = aws_vpc.eks.id
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.cluster_name}-service-${count.index}"
  }
}

# Public subnets to land loadbalancers/NAT/etc.
resource "aws_subnet" "public_eks" {
  count = var.service_subnet_count

  availability_zone       = data.aws_availability_zones.available.names[count.index]
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index + var.service_subnet_count)
  vpc_id                  = aws_vpc.eks.id
  map_public_ip_on_launch = true

  tags = map(
    "Name", "${var.cluster_name}-public-${count.index}",
    "kubernetes.io/cluster/${var.cluster_name}", "shared",
    "kubernetes.io/role/elb", "1",
  )
}

# have the eks subnets come last so that we can add more later.
resource "aws_subnet" "eks" {
  count = var.eks_subnet_count

  availability_zone       = data.aws_availability_zones.available.names[count.index]
  cidr_block              = cidrsubnet(var.vpc_cidr, 6, count.index + 2)
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
  vpc_id = aws_vpc.eks.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.eks.id
  }

  tags = {
    Name = "${var.cluster_name}-eks"
  }
}

resource "aws_route_table_association" "public_eks" {
  count = var.service_subnet_count

  subnet_id      = aws_subnet.public_eks.*.id[count.index]
  route_table_id = aws_route_table.public_eks.id
}

resource "aws_eip" "nat_gateway" {
  count = var.service_subnet_count
  vpc = true
}

resource "aws_nat_gateway" "nat" {
  count = var.service_subnet_count

  allocation_id = aws_eip.nat_gateway.*.id[count.index]
  subnet_id     = aws_subnet.public_eks.*.id[count.index]

  tags = {
    Name = "${var.cluster_name} NAT ${count.index}"
  }
}

resource "aws_route_table" "eks" {
  count = var.eks_subnet_count

  vpc_id = aws_vpc.eks.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.*.id[count.index]
  }

  tags = {
    Name = "${var.cluster_name} route to NAT ${count.index}"
  }
}

resource "aws_route_table_association" "eks" {
  count = var.eks_subnet_count

  subnet_id     = aws_subnet.eks.*.id[count.index]
  route_table_id = aws_route_table.eks.*.id[count.index]
}
