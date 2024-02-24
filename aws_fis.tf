resource "aws_iam_policy" "aws_fis_inject_asg_error" {
  name = "InjectASGErrorsPolicy"
  policy = <<EOT
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "ec2:InjectApiError",
      "Resource": "*",
      "Condition": {
        "ForAllValues:StringEquals": {
          "ec2:FisActionId": [
            "aws:ec2:asg-insufficient-instance-capacity-error"
          ],
          "ec2:FisTargetArns": [
            "${aws_autoscaling_group.multi_az.arn}"
          ]
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": "autoscaling:DescribeAutoScalingGroups",
      "Resource": "*"
    }
  ]
}
EOT
}

resource "aws_iam_role" "aws_fis_role" {
  assume_role_policy    = <<EOT
{
  "Statement": [{
    "Action": "sts:AssumeRole",
    "Effect": "Allow",
    "Principal": {"Service": "fis.amazonaws.com"}
  }],
  "Version": "2012-10-17"
}
EOT
  managed_policy_arns   = ["arn:aws:iam::aws:policy/service-role/AWSFaultInjectionSimulatorNetworkAccess"]

  name                  = "FaultInjectionSimulatorRole"
}

resource "aws_iam_role_policy_attachment" "fis_role_asg_error" {
  role = aws_iam_role.aws_fis_role.name
  policy_arn = aws_iam_policy.aws_fis_inject_asg_error.arn
}

resource "awscc_fis_experiment_template" "disrupt_app_euw2a" {
  actions = {
    prevent-instance-launches = {
      action_id = "aws:ec2:asg-insufficient-instance-capacity-error"
      parameters = {
        duration = "PT30M"
        percentage    = "100"
        availabilityZoneIdentifiers = "eu-west-2a"
      }
      targets = {
        "AutoScalingGroups" = "app-asg"
      }
    }
    disrupt-connectivity-public-subnet = {
      action_id = "aws:network:disrupt-connectivity"
      parameters = {
        duration = "PT30M"
        scope    = "all"
      }
      targets = {
        Subnets = "public-eu-west-2a-subnet"
      }
    }
    disrupt-connectivity-app-subnet = {
      action_id = "aws:network:disrupt-connectivity"
      parameters = {
        duration = "PT30M"
        scope    = "all"
      }
      targets = {
        Subnets = "app-eu-west-2a-subnet"
      }
    }
  }

  description = "Stop app connectivity in eu-west-2a."

  experiment_options = {
    account_targeting            = "single-account"
    empty_target_resolution_mode = "fail"
  }

  role_arn = aws_iam_role.aws_fis_role.arn

  stop_conditions = [
    {
      source = "none"
    }
  ]

  tags = {
    Name = "disrupt-app-euw2a"
  }

  targets = {
    app-asg = {
      resource_arns = [aws_autoscaling_group.multi_az.arn]
      resource_type = "aws:ec2:autoscaling-group"
      selection_mode = "ALL"
    }
    public-eu-west-2a-subnet = {
      resource_arns  = [aws_subnet.this["public-euw2a"].arn]
      resource_type  = "aws:ec2:subnet"
      selection_mode = "ALL"
    }
    app-eu-west-2a-subnet = {
      resource_arns  = [aws_subnet.this["app-euw2a"].arn]
      resource_type  = "aws:ec2:subnet"
      selection_mode = "ALL"
    }
  }
}