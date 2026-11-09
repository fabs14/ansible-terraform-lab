output "instance_ids" {
  description = "EC2 instance IDs by role."
  value       = { for role, instance in aws_instance.lab : role => instance.id }
}

output "frontend_url" {
  description = "Frontend URL after Nginx is configured by Ansible."
  value       = "http://${aws_instance.lab["frontend"].public_ip}"
}

output "inventory_path" {
  description = "Absolute path to the generated Ansible inventory."
  value       = abspath(local_file.inventory.filename)
}
