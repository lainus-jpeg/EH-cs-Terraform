output "peering_connection_id" {
  description = "The ID of the VPC peering connection"
  value       = aws_vpc_peering_connection.main.id
}

output "peering_connection_accept_status" {
  description = "The status of the VPC peering connection acceptance"
  value       = aws_vpc_peering_connection_accepter.main.accept_status
}

output "requester_route_count" {
  description = "Number of routes added to requester route tables"
  value       = length(aws_route.requester_to_accepter)
}

output "accepter_route_count" {
  description = "Number of routes added to accepter route tables"
  value       = length(aws_route.accepter_to_requester)
}
