# infrastructure

# Instruction for downloading teraform

https://learn.hashicorp.com/tutorials/terraform/install-cli

for linux
```
$ curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
$ sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
$ sudo apt-get update && sudo apt-get install terraform
```

# validate the terraform file.
go inside the repo
```
terraform validate 
```

# to view the planning

```
terraform plan
```

# TO build infrastructure
```
terraform apply
```

# To destroy the infrastucture
```
terraform destroy
```
