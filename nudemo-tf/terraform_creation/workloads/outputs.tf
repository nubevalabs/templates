output "source_ip" {
  value       = join("", aws_instance.Source[*].private_ip)
  description = "The private ip address of the source"
}

output "destination_ip" {
  value       = join("", aws_instance.Destination[*].private_ip)
  description = "The destination ip address of the source"
}