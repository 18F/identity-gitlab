package main

import (
	"context"
	"flag"
	"fmt"
	"log"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/cloudwatch"
	"github.com/aws/aws-sdk-go-v2/service/cloudwatch/types"
)

var region = flag.String("region", "us-west-2", "AWS Region")
var cluster_name = flag.String("cluster", "gitlabdemo", "Cluster Name")
var domain = flag.String("domain", "gitlab.identitysandbox.gov", "Domain Suffix")

func main() {
	flag.Parse()

	// Load the SDK's configuration from environment and shared config, and
	// create the client with this.
	cfg, err := config.LoadDefaultConfig(context.TODO(), config.WithRegion(*region))
	if err != nil {
		log.Fatalf("failed to load SDK configuration: %v", err)
	}

	client := cloudwatch.NewFromConfig(cfg)

	datum := types.MetricDatum{
		MetricName: aws.String("ScheduledPipelineSuccess"),
		Value:      aws.Float64(1),
	}

	in := &cloudwatch.PutMetricDataInput{
		MetricData: []types.MetricDatum{
			datum,
		},
		Namespace: aws.String(fmt.Sprintf("%s/gitlab", *cluster_name)),
	}

	_, err = client.PutMetricData(context.TODO(), in)
	if err != nil {
		log.Fatalf("failed to put metric data: %v", err)
	}
}
