package com.franceapi.demo;

import io.restassured.RestAssured;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.notNullValue;

/**
 * Minimal contract tests: they check the invariants required by AGENTS.md §5.
 * For the demo, they target what the fixed spec and code SHOULD guarantee.
 * Some tests are deliberately marked TODO: they fail on the vulnerable version
 * and pass once security-audit-agent has applied its patches.
 */
@SpringBootTest(
        webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT,
        properties = {
                // Spring Boot disables metrics export in tests by default
                // (management.defaults.metrics.export.enabled=false). It is
                // re-enabled here precisely because we WANT to check that
                // /actuator/prometheus is exposed (AGENTS.md §7-A).
                "management.defaults.metrics.export.enabled=true",
                "management.prometheus.metrics.export.enabled=true",
                "management.endpoints.web.exposure.include=health,info,prometheus,metrics"
        }
)
class PaymentContractTest {

    @LocalServerPort int port;

    @BeforeEach
    void setUp() {
        RestAssured.port = port;
    }

    @Test
    void getPayment_returnsBodyWithExpectedFields() {
        given()
            .accept("application/json")
        .when()
            .get("/v1/payments/8f1c0b62-9e15-4b8a-9c3a-2e7b8f7c0001")
        .then()
            .statusCode(200)
            .body("id", notNullValue())
            .body("amount", notNullValue())
            .body("currency", notNullValue());
    }

    @Test
    void actuatorPrometheus_isExposed() {
        // AGENTS.md §7, A. Metrics
        given().when().get("/actuator/prometheus").then().statusCode(200);
    }

    // TODO after remediation: this test must pass.
    // A body with an undocumented field MUST be rejected (400 / 422, RFC 7807).
    // Today it fails because the DTO accepts anything.
    //
    // @Test
    // void createPayment_rejectsMassAssignmentFields() {
    //     given()
    //         .contentType("application/json")
    //         .body("{\"amount\":100,\"currency\":\"EUR\",\"status\":\"CAPTURED\",\"userId\":\"...\"}")
    //     .when()
    //         .post("/v1/payments")
    //     .then()
    //         .statusCode(422)
    //         .contentType("application/problem+json");
    // }
}
