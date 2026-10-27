import pytest
from pydantic import ValidationError

from app.config import Settings


def settings(**overrides):
    return Settings(environment="test", service_key="test-key-" * 5, **overrides)


def test_local_docker_has_no_authentication_requirement():
    config = settings().kafka_client_config()
    assert config["security.protocol"] == "PLAINTEXT"
    assert "sasl.password" not in config


def test_cloud_requires_tls_verification_and_keeps_secret_out_of_repr():
    config = settings(
        kafka_security_protocol="SASL_SSL", kafka_sasl_username="user",
        kafka_sasl_password="test-secret", kafka_ssl_ca_location="/etc/secrets/kafka-ca.pem",
    )
    properties = config.kafka_client_config()
    assert properties["sasl.password"] == "test-secret"
    assert properties["enable.ssl.certificate.verification"] is True
    assert properties["ssl.endpoint.identification.algorithm"] == "https"
    assert properties["ssl.ca.location"] == "/etc/secrets/kafka-ca.pem"
    assert "test-secret" not in repr(config)


def test_missing_credentials_and_unencrypted_sasl_are_rejected():
    with pytest.raises(ValidationError):
        settings(kafka_security_protocol="SASL_SSL")
    with pytest.raises(ValidationError):
        settings(kafka_security_protocol="SASL_PLAINTEXT")
