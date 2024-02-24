# nor(DEV):con 2024 live demo

This repository accompanies the talk I gave at nor(DEV):con 2024, "Anything that can 
fail, will fail."

## Instructions

To run this live demo, a few preparation steps are required.

### 1. Set up AWS credentials

This will deploy **real** resources to AWS and will incur usage costs. Before running 
through the following steps, set up AWS credentials on your command line. You should be 
able to run the following command and see the authenticated AWS identity.

```shell
aws sts get-caller-identity --region eu-west-2
```

### 2. Fill out variables

This Terraform configuration only requires one variable - `route53_zone_name`. The value 
supplied here will be used to create a Route53 hosted zone and later SSL certificate 
validation records and records to point to the EC2 instances that demonstrate single vs. 
multi-AZ resiliency. 

```shell
echo "route53_zone_name = \"\"" > variables.auto.tfvars
```

There will now be a `variables.auto.tfvars` file created in the repository. Populate the 
value of the variable with the DNS zone name you wish to use. For example, I used 
`nordevcon24.alexkearns.co.uk`. This resulted in DNS names like 
`single-az.nordevcon24.alexkearns.co.uk`.

### 3. Deploy infrastructure

```shell
terraform init
terraform apply
```

Once you've started this process, it'll stall whilst it tries to validate the ACM 
SSL certificate. This is because although the DNS records are created in the R53 
hosted zone, the nameservers won't have been updated to point at R53. Jump into the AWS 
console, and take a look at the Route53 hosted zone that's been created. Find the 
value for the record of type `NS` - there should be 4 lines. Wherever the parent domain
(in my case `alexkearns.co.uk`) is configured, you'll need to update the nameservers so 
Route53 can respond to DNS queries made to the domain you supplied as the value for 
`route53_zone_name`.

### 4. Break things!

There's an experiment template created in AWS Fault Injection Simulator to get you 
started. You can use this to simulate an availability zone (`eu-west-2a`) failing and 
watch how this affects the single and multi-AZ examples!

### 5. Tidying up

As I said, this example will incur AWS costs. Please make sure you tidy up when you're 
done. To do this, run the following:

```shell
terraform destroy
```