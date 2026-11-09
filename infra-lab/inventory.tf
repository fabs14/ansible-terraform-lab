resource "local_file" "inventory" {
  filename = "${path.root}/../ansible-lab/inventory.ini"
  content = templatefile("${path.module}/templates/inventory.ini.tftpl", {
    frontend_public_ip  = aws_instance.lab["frontend"].public_ip
    backend_public_ip   = aws_instance.lab["backend"].public_ip
    backend_private_ip  = aws_instance.lab["backend"].private_ip
    database_private_ip = aws_instance.lab["database"].private_ip
  })
}
