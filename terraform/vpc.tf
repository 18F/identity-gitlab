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

resource "aws_subnet" "eks" {
  count = 2

  availability_zone = data.aws_availability_zones.available.names[count.index]
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index)
  vpc_id            = aws_vpc.eks.id
  map_public_ip_on_launch = true

  tags = map(
    "Name", "${var.cluster_name}-node",
    "kubernetes.io/cluster/${var.cluster_name}", "shared",
    "kubernetes.io/role/elb", "1",
    "kubernetes.io/role/internal-elb", ""
  )
}

resource "aws_internet_gateway" "eks" {
  vpc_id = aws_vpc.eks.id

  tags = {
    Name = var.cluster_name
  }
}

resource "aws_route_table" "eks" {
  vpc_id = aws_vpc.eks.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.eks.id
  }
}

resource "aws_route_table_association" "eks" {
  count = 2

  subnet_id      = aws_subnet.eks.*.id[count.index]
  route_table_id = aws_route_table.eks.id
}
