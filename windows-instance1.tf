#This sources a pregenerated key from disk.

provider "aws" {
  region = "eu-west-1"
}

resource "aws_key_pair" "key_pair" {
  key_name   = "test-key"
  public_key = "${file("mykey.pub")}"
}


resource "aws_security_group" "allow_all" {
  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_ami" "windows_ami" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["Windows_Server-2016-English-Full-Base-*"]
  }
}

resource "aws_instance" "ec2" {
  ami               = "${data.aws_ami.windows_ami.image_id}"
  instance_type     = "t2.micro"
  key_name          = "${aws_key_pair.key_pair.key_name}"
  security_groups   = ["${aws_security_group.allow_all.name}"]
  get_password_data = "true"
  user_data = <<EOF
<powershell>

winrm quickconfig -q
winrm set winrm/config/winrs '@{MaxMemoryPerShellMB="300"}'
winrm set winrm/config '@{MaxTimeoutms="1800000"}'
winrm set winrm/config/service '@{AllowUnencrypted="true"}'
winrm set winrm/config/service/auth '@{Basic="true"}'

netsh advfirewall firewall add rule name="WinRM 5985" protocol=TCP dir=in localport=5985 action=allow
netsh advfirewall firewall add rule name="WinRM 5986" protocol=TCP dir=in localport=5986 action=allow

net stop winrm
sc.exe config winrm start=auto
net start winrm
</powershell>
EOF

  provisioner "file" {
    source = "test.txt"
    destination = "C:/test.txt"
  }
  connection {
    type = "winrm"
    timeout = "10m"
    user = "Administrator"
    password = "${rsadecrypt(aws_instance.ec2.password_data, file("mykey"))}"
  }
}


output "instance_id" {
  value = "${aws_instance.ec2.id}"
}

output "ec2_password" { value = "${rsadecrypt(aws_instance.ec2.password_data, file("mykey"))}"}
