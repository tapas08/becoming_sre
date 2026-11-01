/**
 This is a first version of VPC setup. We will start with a rudimentary setup
 and build on top of that.
 */
resource "aws_vpc" "staging_vpc" {
  cidr_block           = "192.168.0.0/16"
  instance_tenancy     = "default"
  enable_dns_hostnames = true
  tags = {
    Name = "sre-playground-staging-vpc",
    App  = "sre-playground"
  }
}

resource "aws_subnet" "staging_subnet_public_01" {
  vpc_id            = aws_vpc.staging_vpc.id
  cidr_block        = "192.168.1.0/24"
  availability_zone = "ap-south-1a"

  tags = {
    Name                     = "sre-playground-staging-subnet-public-01"
    Scope                    = "public"
    App                      = "sre-playground"
    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_subnet" "staging_subnet_public_02" {
  vpc_id            = aws_vpc.staging_vpc.id
  cidr_block        = "192.168.5.0/24"
  availability_zone = "ap-south-1b"

  tags = {
    Name                     = "sre-playground-staging-subnet-public-02"
    Scope                    = "public"
    App                      = "sre-playground"
    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_subnet" "staging_subnet_private_01" {
  vpc_id            = aws_vpc.staging_vpc.id
  cidr_block        = "192.168.2.0/24"
  availability_zone = "ap-south-1a"

  tags = {
    Name                              = "sre-playground-staging-subnet-private-01"
    Scope                             = "private"
    App                               = "sre-playground"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

resource "aws_subnet" "staging_subnet_private_02" {
  vpc_id            = aws_vpc.staging_vpc.id
  cidr_block        = "192.168.4.0/24"
  availability_zone = "ap-south-1b"

  tags = {
    Name                              = "sre-playground-staging-subnet-private-02"
    Scope                             = "private"
    App                               = "sre-playground"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

resource "aws_subnet" "staging_subnet_db_01" {
  vpc_id            = aws_vpc.staging_vpc.id
  cidr_block        = "192.168.3.0/24"
  availability_zone = "ap-south-1a"

  tags = {
    Name  = "sre-playground-staging-subnet-db-01"
    Scope = "db"
    App   = "sre-playground"
  }
}

resource "aws_internet_gateway" "staging_igw" {
  vpc_id = aws_vpc.staging_vpc.id

  tags = {
    Name = "sre-playground-staging-igw"
    App  = "sre-playground"
  }
}

resource "aws_route_table" "staging_public_rt" {
  vpc_id = aws_vpc.staging_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.staging_igw.id
  }

  tags = {
    Name = "sre-playground-staging-public-rt"
    App  = "sre-playground"
  }
}

resource "aws_route_table_association" "staging_public_route_association_01" {
  route_table_id = aws_route_table.staging_public_rt.id
  subnet_id      = aws_subnet.staging_subnet_public_01.id
}

resource "aws_route_table_association" "staging_public_route_association_02" {
  route_table_id = aws_route_table.staging_public_rt.id
  subnet_id      = aws_subnet.staging_subnet_public_02.id
}

# NAT Gateway Setup
resource "aws_eip" "nat" {
  domain = "vpc"
}

resource "aws_nat_gateway" "staging_natgateway" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.staging_subnet_public_01.id
  depends_on    = [aws_subnet.staging_subnet_public_01]
}

resource "aws_route_table" "staging_private_rt" {
  vpc_id = aws_vpc.staging_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.staging_natgateway.id
  }

  tags = {
    Name = "sre-playground-staging-private-rt"
    App  = "sre-playground"
  }
}

resource "aws_route_table_association" "staging_private_rt_association_01" {
  route_table_id = aws_route_table.staging_private_rt.id
  subnet_id      = aws_subnet.staging_subnet_private_01.id
}

resource "aws_route_table_association" "staging_private_rt_association_02" {
  route_table_id = aws_route_table.staging_private_rt.id
  subnet_id      = aws_subnet.staging_subnet_private_02.id
}