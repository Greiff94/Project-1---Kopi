package test

import (
	"fmt"
	"testing"

	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
)

func TestWebUnit(t *testing.T) {
	t.Parallel()

	uniqueID := random.UniqueId()

	terraformOptions := &terraform.Options{
		TerraformDir: "..",

		Vars: map[string]interface{}{
			"name": fmt.Sprintf("web_server-%s", uniqueID),
		},
	}
	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)
	validate(t, terraformOptions)
}

/*  */
/* func validate(t *testing.T, opts *terraform.Options) { */
/* 	url := terraform.Output(t, opts, "url") */
/* 	expectedStatus := 200 */
/* 	expectedBody := "my first web server" */
/* 	maxRetries := 10 */
/* 	timeBetweenRetries := 3 * time.Second */
/* 	http_helper.HttpGetWithRetry(t, url, nil, expectedStatus, expectedBody , maxRetries, timeBetweenRetries)*/
/* } */
/*  */
