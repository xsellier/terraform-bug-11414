provider "aws" {
  region = "us-east-1"
}

resource "aws_ecs_cluster" "cluster" {
  name = "test-cluster"
}

resource "aws_ecs_service" "service" {
  name = "test"

  cluster = "${aws_ecs_cluster.cluster.id}"
  task_definition = "${aws_ecs_task_definition.task.arn}"
  desired_count = "1"

  deployment_maximum_percent = 200
  deployment_minimum_healthy_percent = 100
}

resource "aws_appautoscaling_target" "service_asg" {
  service_namespace = "ecs"
  resource_id = "service/${aws_ecs_cluster.cluster.name}/${aws_ecs_service.service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  role_arn = "${aws_iam_role.service.arn}"

  min_capacity = "${var.min_size}"
  max_capacity = "${var.max_size}"

  depends_on = [
    "aws_ecs_service.service"
  ]
}

resource "aws_appautoscaling_policy" "service_down" {
  name = "test-asp-down"
  service_namespace = "ecs"
  resource_id = "service/${aws_ecs_cluster.cluster.name}/${aws_ecs_service.service.name}"
  scalable_dimension = "ecs:service:DesiredCount"

  adjustment_type = "ChangeInCapacity"
  cooldown = 60
  metric_aggregation_type = "Average"

  step_adjustment {
    metric_interval_lower_bound = 0
    scaling_adjustment = -1
  }

  depends_on = ["aws_appautoscaling_target.service_asg"]
}

resource "aws_cloudwatch_metric_alarm" "cpu_service_down" {
  alarm_name = "test-cpu-alarm-down"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods = "10"
  metric_name = "CPUUtilization"

  namespace = "AWS/ECS"
  period = "60"

  statistic = "Average"
  threshold = "45"
  unit = "Percent"

  dimensions {
    ServiceName = "${aws_ecs_service.service.name}"
    ClusterName = "${aws_ecs_cluster.cluster.name}"
  }

  alarm_description = "This metric monitors low cpu utilization of test"
}

resource "aws_cloudwatch_metric_alarm" "mem_service_down" {
  alarm_name = "test-mem-alarm-down"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods = "10"
  metric_name = "MemoryUtilization"

  namespace = "AWS/ECS"
  period = "60"

  statistic = "Average"
  threshold = "35"
  unit = "Percent"

  dimensions {
    ServiceName = "${aws_ecs_service.service.name}"
    ClusterName = "${aws_ecs_cluster.cluster.name}"
  }

  alarm_description = "This metric monitors memory utilization (down) for test"
}

resource "aws_appautoscaling_policy" "service_up" {
  name = "test-asp-up"
  service_namespace = "ecs"
  resource_id = "service/${aws_ecs_cluster.cluster.name}/${aws_ecs_service.service.name}"
  scalable_dimension = "ecs:service:DesiredCount"

  adjustment_type = "ChangeInCapacity"
  cooldown = 60
  metric_aggregation_type = "Average"

  step_adjustment {
    metric_interval_lower_bound = 0
    metric_interval_upper_bound = 50
    scaling_adjustment = 1
  }

  step_adjustment {
    metric_interval_lower_bound = 50
    scaling_adjustment = 2
  }


  depends_on = ["aws_appautoscaling_target.service_asg"]
}

resource "aws_cloudwatch_metric_alarm" "cpu_service_up" {
  alarm_name = "test-cpu-alarm-up"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods = "1"
  metric_name = "CPUUtilization"

  namespace = "AWS/ECS"
  period = "60"

  statistic = "Maximum"
  threshold = "65"
  unit = "Percent"

  dimensions {
    ServiceName = "${aws_ecs_service.service.name}"
    ClusterName = "${aws_ecs_cluster.cluster.name}"
  }

  alarm_description = "This metric monitors high cpu utilization of test"
  alarm_actions = ["${aws_appautoscaling_policy.service_up.arn}"]
}

resource "aws_cloudwatch_metric_alarm" "mem_service_up" {
  alarm_name = "test-mem-alarm-up"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods = "1"
  metric_name = "MemoryUtilization"

  namespace = "AWS/ECS"
  period = "60"

  statistic = "Maximum"
  threshold = "75"
  unit = "Percent"

  dimensions {
    ServiceName = "${aws_ecs_service.service.name}"
    ClusterName = "${aws_ecs_cluster.cluster.name}"
  }

  alarm_description = "This metric monitors memory utilization (up) for test"
  alarm_actions = ["${aws_appautoscaling_policy.service_up.arn}"]
}

resource "aws_ecs_task_definition" "task" {
  family = "service"
  container_definitions = "${file("${path.module}/task-definitions/service.json")}"
  network_mode = "bridge"
}

# IAM profile to be used in auto-scaling launch configuration.
resource "aws_iam_instance_profile" "service" {
  name = "test-instance-profile"
  path = "/test/"
  roles = ["${aws_iam_role.service.name}"]
}

resource "aws_iam_role" "service" {
  name = "test-role"
  assume_role_policy = "${file("${path.module}/policy/ecs-role.json")}"
}

resource "aws_iam_role_policy" "service" {
  name = "test-role-policy"
  policy = "${file("${path.module}/policy/ecs-service-role-policy.json")}"
  role = "${aws_iam_role.service.id}"
}


variable "min_size" {}
variable "max_size" {}