#include "headers/publisher.h"

volatile sig_atomic_t running = 1;

pthread_t temperature_sender_thread;
pthread_mutex_t mqtt_mutex = PTHREAD_MUTEX_INITIALIZER;

const char *classId = "01-ilaario-room";

const char *temperatureTopic = "unizar/eina/01-ilaario-room/temperature";
const char *occupancyTopic   = "unizar/eina/01-ilaario-room/occupancy";
const char *statusTopic      = "unizar/eina/01-ilaario-room/status";
const char *alertTopic       = "unizar/eina/alerts";

int occupancy_current = 0;
const int occupancy_max = 30;
int class_active = 0;

void handle_sigint(int sig) {
    (void)sig;
    running = 0;
}

void get_utc_timestamp(char *buffer, size_t size) {
    time_t now = time(NULL);
    struct tm *utc = gmtime(&now);

    strftime(buffer, size, "%Y-%m-%dT%H:%M:%S+00:00", utc);
}

double gaussian_random(double mean, double stddev) {
    double u1 = ((double) rand() + 1.0) / ((double) RAND_MAX + 1.0);
    double u2 = ((double) rand() + 1.0) / ((double) RAND_MAX + 1.0);
    double z0 = sqrt(-2.0 * log(u1)) * cos(2.0 * M_PI * u2);

    return mean + z0 * stddev;
}

double round_to_1_decimal(double value) {
    return round(value * 10.0) / 10.0;
}

int publish_payload(MQTTClient client, const char *topic, const char *payload, int qos) {
    MQTTClient_deliveryToken token;
    int rc;

    pthread_mutex_lock(&mqtt_mutex);

    rc = MQTTClient_publish(
        client,
        topic,
        (int)strlen(payload),
        payload,
        qos,
        0,
        &token
    );

    if (rc == MQTTCLIENT_SUCCESS && qos > 0) {
        rc = MQTTClient_waitForCompletion(client, token, 10000L);
    }

    pthread_mutex_unlock(&mqtt_mutex);

    if (rc != MQTTCLIENT_SUCCESS) {
        fprintf(stderr, "[ERROR] Failed to publish on %s, return code: %d\n", topic, rc);
    }

    return rc;
}

void publish_occupancy(MQTTClient client) {
    char ts[32];
    char payload[128];

    get_utc_timestamp(ts, sizeof(ts));

    snprintf(
        payload,
        sizeof(payload),
        "{\"current\": %d, \"max\": %d, \"ts\": \"%s\"}",
        occupancy_current,
        occupancy_max,
        ts
    );

    if (publish_payload(client, occupancyTopic, payload, 1) == MQTTCLIENT_SUCCESS) {
        printf("[INFO] Occupancy sent: %s\n", payload);
    }
}

void publish_class_status(MQTTClient client) {
    char ts[32];
    char payload[128];

    get_utc_timestamp(ts, sizeof(ts));

    snprintf(
        payload,
        sizeof(payload),
        "{\"active\": %s, \"ts\": \"%s\"}",
        class_active ? "true" : "false",
        ts
    );

    if (publish_payload(client, statusTopic, payload, 1) == MQTTCLIENT_SUCCESS) {
        printf("[INFO] Class status sent: %s\n", payload);
    }
}

void publish_overcapacity_alert(MQTTClient client) {
    char ts[32];
    char payload[256];

    get_utc_timestamp(ts, sizeof(ts));

    snprintf(
        payload,
        sizeof(payload),
        "{\"room\": \"%s\", \"type\": \"overcapacity\", "
        "\"message\": \"Room at max capacity (%d/%d)\", "
        "\"ts\": \"%s\"}",
        classId,
        occupancy_current,
        occupancy_max,
        ts
    );

    if (publish_payload(client, alertTopic, payload, 1) == MQTTCLIENT_SUCCESS) {
        printf("[INFO] Overcapacity alert sent: %s\n", payload);
    }
}

void check_capacity_alert(MQTTClient client) {
    if (occupancy_current >= occupancy_max) {
        publish_overcapacity_alert(client);
    }
}

void publish_device_offline(MQTTClient client) {
    char payload[256];

    snprintf(
        payload,
        sizeof(payload),
        "{\"room\": \"%s\", \"type\": \"device_offline\", "
        "\"message\": \"Room %s: device lost connection unexpectedly\"}",
        classId,
        classId
    );

    if (publish_payload(client, alertTopic, payload, 1) == MQTTCLIENT_SUCCESS) {
        printf("[INFO] Device offline sent: %s\n", payload);
    }
}

void *temperature_sender(void *arg) {
    MQTTClient client = (MQTTClient)arg;

    while (running) {
        double temp = round_to_1_decimal(20.0 + gaussian_random(0.0, 0.5));

        char ts[32];
        char payload[128];

        get_utc_timestamp(ts, sizeof(ts));

        snprintf(
            payload,
            sizeof(payload),
            "{\"value\": %.1f, \"ts\": \"%s\"}",
            temp,
            ts
        );

        int rc = publish_payload(client, temperatureTopic, payload, 0);

        if (rc != MQTTCLIENT_SUCCESS) {
            running = 0;
            break;
        }

        for (int s = 0; s < 5 && running; s++) {
            sleep(1);
        }
    }

    return NULL;
}

int main() {
    signal(SIGINT, handle_sigint);
    srand(time(NULL));

    int rc = 0;

    const char *clientid = "ilaario";
    const char *broker = "tcp://broker.hivemq.com:1883";

    MQTTClient client;

    rc = MQTTClient_create(
        &client,
        broker,
        clientid,
        MQTTCLIENT_PERSISTENCE_NONE,
        NULL
    );

    if (rc != MQTTCLIENT_SUCCESS) {
        fprintf(stderr, "Error creating MQTTClient, return code: %d\n", rc);
        exit(EXIT_FAILURE);
    }

    MQTTClient_connectOptions conn_opts = MQTTClient_connectOptions_initializer;

    conn_opts.MQTTVersion = MQTTVERSION_3_1_1;
    conn_opts.keepAliveInterval = 20;
    conn_opts.cleansession = 1;

    rc = MQTTClient_connect(client, &conn_opts);

    if (rc != MQTTCLIENT_SUCCESS) {
        fprintf(stderr, "Failed to connect, return code: %d\n", rc);
        MQTTClient_destroy(&client);
        exit(EXIT_FAILURE);
    }

    printf("[INFO] Client connected with id: %s\n", clientid);

    if (pthread_create(&temperature_sender_thread, NULL, temperature_sender, (void *)client) != 0) {
        fprintf(stderr, "Errore nella creazione del thread\n");
        MQTTClient_disconnect(client, 10000);
        MQTTClient_destroy(&client);
        return 1;
    }

    printf("\nCommands:\n");
    printf("  +  person enters room\n");
    printf("  -  person leaves room\n");
    printf("  c  toggle class status\n");
    printf("  q  quit\n\n");

    while (running) {
        int ch = getchar();

        if (ch == '\n') {
            continue;
        }

        switch (ch) {
            case '+':
                if (occupancy_current < occupancy_max) {
                    occupancy_current++;
                }

                publish_occupancy(client);
                check_capacity_alert(client);
                break;

            case '-':
                if (occupancy_current > 0) {
                    occupancy_current--;
                }

                publish_occupancy(client);
                check_capacity_alert(client);
                break;

            case 'c':
                class_active = !class_active;
                publish_class_status(client);
                break;

            case 'q':
                running = 0;
                publish_device_offline(client);
                break;

            default:
                printf("[WARN] Unknown command: %c\n", ch);
                break;
        }
    }

    pthread_join(temperature_sender_thread, NULL);

    printf("\n[INFO] Closing MQTT connection...\n");

    MQTTClient_disconnect(client, 10000);
    MQTTClient_destroy(&client);

    pthread_mutex_destroy(&mqtt_mutex);

    printf("[INFO] Disconnected cleanly.\n");

    return 0;
}