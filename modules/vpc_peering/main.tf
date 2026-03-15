# VPC Peering Connection
resource "aws_vpc_peering_connection" "main" {
  vpc_id      = var.requester_vpc_id
  peer_vpc_id = var.accepter_vpc_id

  tags = {
    Name = "apps-to-monitoring-peering"
  }
}

# Accept the peering connection from the accepter side
resource "aws_vpc_peering_connection_accepter" "main" {
  vpc_peering_connection_id = aws_vpc_peering_connection.main.id
  auto_accept               = true

  tags = {
    Name = "monitoring-accept-peering"
  }
}

# Routes in Requester (Apps) VPC - to Accepter (Monitoring) VPC
resource "aws_route" "requester_to_accepter" {
  count                     = length(var.requester_route_table_ids)
  route_table_id            = var.requester_route_table_ids[count.index]
  destination_cidr_block    = var.accepter_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.main.id

  depends_on = [aws_vpc_peering_connection_accepter.main]
}

# Routes in Accepter (Monitoring) VPC - to Requester (Apps) VPC
resource "aws_route" "accepter_to_requester" {
  count                     = length(var.accepter_route_table_ids)
  route_table_id            = var.accepter_route_table_ids[count.index]
  destination_cidr_block    = var.requester_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.main.id

  depends_on = [aws_vpc_peering_connection_accepter.main]
}
