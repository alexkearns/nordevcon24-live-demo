resource "aws_vpc" "this" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "summer-crabtacular"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "summer-crabtacular"
  }
}

resource "aws_eip" "nat_gateway" {
  for_each = local.availability_zones

  tags = {
    Name = "summer-crabtacular-natgw-${each.value}"
  }
}

resource "aws_nat_gateway" "this" {
  for_each = local.availability_zones

  subnet_id     = aws_subnet.this["public-${each.value}"].id
  allocation_id = aws_eip.nat_gateway[each.key].id

  tags = {
    Name = "summer-crabtacular-${each.value}"
  }
}

resource "aws_subnet" "this" {
  for_each = local.subnets

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value.cidr_block
  availability_zone = each.value.az

  tags = {
    Name = "summer-crabtacular-${each.key}"
    Tier = each.value.tier
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name = "summer-crabtacular-public"
  }
}

resource "aws_route_table_association" "public" {
  for_each = { for k, s in aws_subnet.this : k => s.id if s.tags.Tier == "public" }

  subnet_id      = each.value
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "application" {
  for_each = { for k, s in aws_subnet.this : k => s.id if s.tags.Tier == "app" }

  vpc_id = aws_vpc.this.id

  tags = {
    Name = "summer-crabtacular-${each.key}"
  }
}

resource "aws_route" "application_to_natgw" {
  for_each = { for k, s in aws_subnet.this : k => s if s.tags.Tier == "app" }

  route_table_id = aws_route_table.application[each.key].id

  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[each.value.availability_zone].id
}

resource "aws_route_table_association" "application" {
  for_each = { for k, s in aws_subnet.this : k => s.id if s.tags.Tier == "app" }

  subnet_id      = each.value
  route_table_id = aws_route_table.application[each.key].id
}
