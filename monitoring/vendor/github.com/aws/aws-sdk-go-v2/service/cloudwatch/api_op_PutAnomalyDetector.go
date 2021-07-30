// Code generated by smithy-go-codegen DO NOT EDIT.

package cloudwatch

import (
	"context"
	awsmiddleware "github.com/aws/aws-sdk-go-v2/aws/middleware"
	"github.com/aws/aws-sdk-go-v2/aws/signer/v4"
	"github.com/aws/aws-sdk-go-v2/service/cloudwatch/types"
	"github.com/aws/smithy-go/middleware"
	smithyhttp "github.com/aws/smithy-go/transport/http"
)

// Creates an anomaly detection model for a CloudWatch metric. You can use the
// model to display a band of expected normal values when the metric is graphed.
// For more information, see CloudWatch Anomaly Detection
// (https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch_Anomaly_Detection.html).
func (c *Client) PutAnomalyDetector(ctx context.Context, params *PutAnomalyDetectorInput, optFns ...func(*Options)) (*PutAnomalyDetectorOutput, error) {
	if params == nil {
		params = &PutAnomalyDetectorInput{}
	}

	result, metadata, err := c.invokeOperation(ctx, "PutAnomalyDetector", params, optFns, c.addOperationPutAnomalyDetectorMiddlewares)
	if err != nil {
		return nil, err
	}

	out := result.(*PutAnomalyDetectorOutput)
	out.ResultMetadata = metadata
	return out, nil
}

type PutAnomalyDetectorInput struct {

	// The name of the metric to create the anomaly detection model for.
	//
	// This member is required.
	MetricName *string

	// The namespace of the metric to create the anomaly detection model for.
	//
	// This member is required.
	Namespace *string

	// The statistic to use for the metric and the anomaly detection model.
	//
	// This member is required.
	Stat *string

	// The configuration specifies details about how the anomaly detection model is to
	// be trained, including time ranges to exclude when training and updating the
	// model. You can specify as many as 10 time ranges. The configuration can also
	// include the time zone to use for the metric.
	Configuration *types.AnomalyDetectorConfiguration

	// The metric dimensions to create the anomaly detection model for.
	Dimensions []types.Dimension
}

type PutAnomalyDetectorOutput struct {
	// Metadata pertaining to the operation's result.
	ResultMetadata middleware.Metadata
}

func (c *Client) addOperationPutAnomalyDetectorMiddlewares(stack *middleware.Stack, options Options) (err error) {
	err = stack.Serialize.Add(&awsAwsquery_serializeOpPutAnomalyDetector{}, middleware.After)
	if err != nil {
		return err
	}
	err = stack.Deserialize.Add(&awsAwsquery_deserializeOpPutAnomalyDetector{}, middleware.After)
	if err != nil {
		return err
	}
	if err = addSetLoggerMiddleware(stack, options); err != nil {
		return err
	}
	if err = awsmiddleware.AddClientRequestIDMiddleware(stack); err != nil {
		return err
	}
	if err = smithyhttp.AddComputeContentLengthMiddleware(stack); err != nil {
		return err
	}
	if err = addResolveEndpointMiddleware(stack, options); err != nil {
		return err
	}
	if err = v4.AddComputePayloadSHA256Middleware(stack); err != nil {
		return err
	}
	if err = addRetryMiddlewares(stack, options); err != nil {
		return err
	}
	if err = addHTTPSignerV4Middleware(stack, options); err != nil {
		return err
	}
	if err = awsmiddleware.AddRawResponseToMetadata(stack); err != nil {
		return err
	}
	if err = awsmiddleware.AddRecordResponseTiming(stack); err != nil {
		return err
	}
	if err = addClientUserAgent(stack); err != nil {
		return err
	}
	if err = smithyhttp.AddErrorCloseResponseBodyMiddleware(stack); err != nil {
		return err
	}
	if err = smithyhttp.AddCloseResponseBodyMiddleware(stack); err != nil {
		return err
	}
	if err = addOpPutAnomalyDetectorValidationMiddleware(stack); err != nil {
		return err
	}
	if err = stack.Initialize.Add(newServiceMetadataMiddleware_opPutAnomalyDetector(options.Region), middleware.Before); err != nil {
		return err
	}
	if err = addRequestIDRetrieverMiddleware(stack); err != nil {
		return err
	}
	if err = addResponseErrorMiddleware(stack); err != nil {
		return err
	}
	if err = addRequestResponseLogging(stack, options); err != nil {
		return err
	}
	return nil
}

func newServiceMetadataMiddleware_opPutAnomalyDetector(region string) *awsmiddleware.RegisterServiceMetadata {
	return &awsmiddleware.RegisterServiceMetadata{
		Region:        region,
		ServiceID:     ServiceID,
		SigningName:   "monitoring",
		OperationName: "PutAnomalyDetector",
	}
}
