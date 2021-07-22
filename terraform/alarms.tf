# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "runner_alarm" {
  alarm_name                = "GitLab Runner Unhealthy"
  comparison_operator       = "LessThanThreshold"
  evaluation_periods        = "1"
  metric_name               = "ScheduledPipelineSuccess"
  namespace                 = "${var.cluster_name}/gitlab"
  period                    = "900"
  statistic                 = "SampleCount"
  threshold                 = "1"
  alarm_description         = "This Alarm is executed if no runner has successfully completed in the last 15m."
  insufficient_data_actions = []
  alarm_actions             = [
    "arn:aws:sns:${var.region}:${data.aws_caller_identity.current.account_id}:slack-otherevents",
  ]
}
