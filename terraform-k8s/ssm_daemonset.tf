resource "kubernetes_daemonset" "daemonset_ssm_installer" {
  metadata {
    labels = {
      k8s-app = "ssm-installer"
    }
    name      = "ssm-installer"
    namespace = "default"
  }
  spec {
    selector {
      match_labels = {
        k8s-app = "ssm-installer"
      }
    }
    template {
      metadata {
        labels = {
          k8s-app = "ssm-installer"
        }
      }
      spec {
        container {
            args = [
              "-c",
              "echo '* * * * * root yum install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm & rm -rf /etc/cron.d/ssmstart' > /etc/cron.d/ssmstart",
            ]
            command = [
              "/bin/bash",
            ]
            image           = "amazonlinux"
            image_pull_policy = "Always"
            name            = "ssm"
            security_context {
              allow_privilege_escalation = true
            }
            termination_message_path   = "/dev/termination-log"
            volume_mount {
                mount_path = "/etc/cron.d"
                name      = "cronfile"
              }
        }
        dns_policy                     = "ClusterFirst"
        restart_policy                 = "Always"
        termination_grace_period_seconds = 30
        volume {
            host_path {
              path = "/etc/cron.d"
              type = "Directory"
            }
            name = "cronfile"
        }
      }
    }
  }
}
