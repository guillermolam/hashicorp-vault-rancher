// terraform/modules/vault/tests/vault_test.go
package tests

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
)

func TestVaultModuleBasicCreation(t *testing.T) {
	// Construct the terraform options with default retryable errors
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		// Set the path to the Terraform code that will be tested
		TerraformDir: "../",

		// Specify terraform as the binary to use (not tofu)
		TerraformBinary: "terraform",

		// Variables to pass to our Terraform code using -var options
		Vars: map[string]interface{}{
			"name":          "vault-test",
			"ha_enabled":    false,
			"replica_count": 1,
		},

		// Don't actually apply changes
		NoColor: true,
	})

	// Run `terraform init` and `terraform plan`. Fail the test if there are any errors.
	terraform.InitAndPlan(t, terraformOptions)
}

// A more advanced test that can work with Terragrunt
func TestVaultWithTerragrunt(t *testing.T) {
	// Skip this test if we're not in the CI environment with Terragrunt
	if os.Getenv("CI_WITH_TERRAGRUNT") != "true" {
		t.Skip("Skipping Terragrunt test in non-CI environment")
	}

	terragruntOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir:    filepath.Join("..", "..", "..", "terragrunt", "modules", "vault"),
		TerraformBinary: "terragrunt",
	})

	// Run `terragrunt validate`
	terraform.RunTerraformCommand(t, terragruntOptions, "validate")
}
