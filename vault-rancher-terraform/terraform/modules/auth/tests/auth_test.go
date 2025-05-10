// terraform/modules/auth/tests/auth_test.go
package tests

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
)

func TestAuthModuleBasicCreation(t *testing.T) {
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../",

		Vars: map[string]interface{}{
			"vault_name":         "vault-test",
			"namespace":          "vault",
			"oidc_discovery_url": "https://example.auth0.com/",
			"oidc_client_id":     "test-client-id",
			"oidc_client_secret": "test-client-secret",
			"oidc_redirect_uri":  "https://vault.example.com/oidc/callback",
			"oidc_scopes":        []string{"openid", "profile", "email"},
			"oidc_groups_claim":  "groups",
		},

		NoColor: true,
	})

	terraform.InitAndPlan(t, terraformOptions)
}
