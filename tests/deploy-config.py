import json
import os
import subprocess
import unittest

BASE = ["docker", "compose", "-f", "deploy/docker-compose.yml"]

class DeployConfig(unittest.TestCase):
    def config(self, override=None, **variables):
        env = os.environ.copy()
        env.update(variables)
        args = BASE + (["-f", override] if override else []) + ["config", "--format", "json"]
        return subprocess.run(args, env=env, capture_output=True, text=True)

    def test_empty_seed_stays_empty(self):
        result = self.config(SEED_ON_BOOT="")
        self.assertEqual(result.returncode, 0)
        self.assertEqual(json.loads(result.stdout)["services"]["backend"]["environment"]["SEED_ON_BOOT"], "")

    def test_empty_password_not_replaced_by_demo(self):
        result = self.config(POSTGRES_PASSWORD="")
        self.assertEqual(result.returncode, 0)
        self.assertEqual(json.loads(result.stdout)["services"]["db"]["environment"]["POSTGRES_PASSWORD"], "")

    def test_production_requires_password(self):
        result = self.config("deploy/docker-compose.production.yml", POSTGRES_PASSWORD="")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("POSTGRES_PASSWORD", result.stderr)

    def test_production_gates_and_tls(self):
        result = self.config("deploy/docker-compose.production.yml", POSTGRES_PASSWORD="config-test-placeholder", SEED_ON_BOOT="1", SIM_ENABLED="1", DEMO_ROLE_SWITCH="1", AUTH_COOKIE_SECURE="0", SCREEN_PUBLIC="1")
        self.assertEqual(result.returncode, 0, result.stderr)
        services = json.loads(result.stdout)["services"]
        env = services["backend"]["environment"]
        for key, value in {"SEED_ON_BOOT":"0", "SIM_ENABLED":"0", "DEMO_ROLE_SWITCH":"0", "AUTH_COOKIE_SECURE":"1", "SCREEN_PUBLIC":"0"}.items():
            self.assertEqual(env[key], value)
        self.assertIn(443, [p["target"] for p in services["web"]["ports"]])
        for mount in services["web"]["volumes"]:
            self.assertFalse(mount["bind"].get("create_host_path", False))
        self.assertEqual(services["web"]["depends_on"]["backend"]["condition"], "service_healthy")

    def test_cloud_start_rejects_external_database_before_startup(self):
        env = os.environ.copy()
        env["DATABASE_URL"] = "postgres://localhost/external_db?sslmode=disable"
        result = subprocess.run(["scripts/cloud-dev.sh", "start"], env=env, capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("only manages the project demo database", result.stderr)

    def test_unknown_cloud_command_has_no_startup_side_effect(self):
        result = subprocess.run(["scripts/cloud-dev.sh", "invalid"], capture_output=True, text=True)
        self.assertEqual(result.returncode, 2)
        self.assertIn("Usage:", result.stderr)

    def test_all_services_have_bounded_logs(self):
        result = self.config()
        self.assertEqual(result.returncode, 0)
        for service in json.loads(result.stdout)["services"].values():
            self.assertEqual(service["logging"]["driver"], "json-file")
            self.assertEqual(service["logging"]["options"], {"max-size":"10m", "max-file":"3"})

if __name__ == "__main__":
    unittest.main()
