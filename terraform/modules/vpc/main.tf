# VPC(AWS에서 사용하는 사설 네트워크의 최상위 경계)
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-${var.environment}-vpc"
  }
}

# Internet Gateway(VPC를 공용 인터넷과 연결해 주는 게이트)
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-${var.environment}-igw"
  }
}

# 가용 영역 데이터 소스
data "aws_availability_zones" "available" {
  state = "available"
}

# Public Subnet (Nginx 게이트웨이 전용)
# 인터넷에 직접 노출되는 유일한 서브넷, Nginx만 배치
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name    = "${var.project_name}-${var.environment}-nginx-public-subnet"
    Type    = "Public"
    Purpose = "Nginx Gateway Only"
  }
}

# Public Route Table (Nginx용 - Internet Gateway 직접 연결)
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name    = "${var.project_name}-${var.environment}-nginx-public-rt"
    Purpose = "Nginx Gateway Internet Access"
  }
}

# Public Route Table Association
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Private Subnet (애플리케이션 서버용 - 메인/AI 서버)
# 외부 직접 접근 불가, Nginx NAT를 통해서만 아웃바운드 가능
resource "aws_subnet" "private" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_subnet_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = false

  tags = {
    Name    = "${var.project_name}-${var.environment}-app-private-subnet"
    Type    = "Private"
    Purpose = "Main & AI Services"
  }
}

# Private Route Table (Nginx NAT를 통한 아웃바운드)
# NAT 라우트(0.0.0.0/0 → Nginx ENI)는 Compute 모듈에서 추가됨
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name    = "${var.project_name}-${var.environment}-app-private-rt"
    Purpose = "Application Servers via Nginx NAT"
  }
}

# Private Route Table Association
resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}
