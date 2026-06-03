#include "headers/subscriber.h"

volatile sig_atomic_t running = 1;

void handle_sigint(int sig) {
    (void)sig;
    running = 0;
}

void get_current_utc_timestamp(char *buffer, size_t size) {
    time_t now = time(NULL);
    struct tm *utc = gmtime(&now);

    strftime(buffer, size, "%Y-%m-%dT%H:%M:%S+00:00", utc);
}

int extract_json_string(
    const char *json,
    const char *key,
    char *output,
    size_t output_size
) {
    char pattern[64];
    snprintf(pattern, sizeof(pattern), "\"%s\"", key);

    char *key_pos = strstr(json, pattern);
    if (key_pos == NULL) {
        return 0;
    }

    char *colon = strchr(key_pos, ':');
    if (colon == NULL) {
        return 0;
    }

    char *start_quote = strchr(colon, '"');
    if (start_quote == NULL) {
        return 0;
    }

    start_quote++;

    char *end_quote = strchr(start_quote, '"');
    if (end_quote == NULL) {
        return 0;
    }

    size_t len = (size_t)(end_quote - start_quote);

    if (len >= output_size) {
        len = output_size - 1;
    }

    strncpy(output, start_quote, len);
    output[len] = '\0';

    return 1;
}

void print_formatted_alert(const char *payload) {
    char room[64] = "unknown-room";
    char type[64] = "unknown";
    char message[256] = "No message";
    char ts[64];

    get_current_utc_timestamp(ts, sizeof(ts));

    extract_json_string(payload, "room", room, sizeof(room));
    extract_json_string(payload, "type", type, sizeof(type));
    extract_json_string(payload, "message", message, sizeof(message));
    extract_json_string(payload, "ts", ts, sizeof(ts));

    const char *label;

    if (strcmp(type, "overcapacity") == 0) {
        label = "OVERCAPACITY";
    } else if (strcmp(type, "device_offline") == 0) {
        label = "OFFLINE";
    } else {
        label = type;
    }

    printf("%s [%s] Room %s %s\n", ts, label, room, message);
    fflush(stdout);
}

int message_arrived(
    void *context,
    char *topicName,
    int topicLen,
    MQTTClient_message *message
) {
    (void)context;
    (void)topicLen;

    char *payload = malloc((size_t)message->payloadlen + 1);

    if (payload == NULL) {
        fprintf(stderr, "[ERROR] Failed to allocate memory for payload\n");

        MQTTClient_freeMessage(&message);
        MQTTClient_free(topicName);

        return 1;
    }

    memcpy(payload, message->payload, (size_t)message->payloadlen);
    payload[message->payloadlen] = '\0';

    print_formatted_alert(payload);

    free(payload);

    MQTTClient_freeMessage(&message);
    MQTTClient_free(topicName);

    return 1;
}

void connection_lost(void *context, char *cause) {
    (void)context;

    fprintf(stderr, "[ERROR] Connection lost");

    if (cause != NULL) {
        fprintf(stderr, ": %s", cause);
    }

    fprintf(stderr, "\n");

    running = 0;
}

int main(void) {
    signal(SIGINT, handle_sigint);

    MQTTClient client;
    MQTTClient_connectOptions conn_opts = MQTTClient_connectOptions_initializer;

    int rc;

    rc = MQTTClient_create(
        &client,
        BROKER,
        CLIENTID,
        MQTTCLIENT_PERSISTENCE_NONE,
        NULL
    );

    if (rc != MQTTCLIENT_SUCCESS) {
        fprintf(stderr, "[ERROR] Failed to create client, return code: %d\n", rc);
        return EXIT_FAILURE;
    }

    rc = MQTTClient_setCallbacks(
        client,
        NULL,
        connection_lost,
        message_arrived,
        NULL
    );

    if (rc != MQTTCLIENT_SUCCESS) {
        fprintf(stderr, "[ERROR] Failed to set callbacks, return code: %d\n", rc);
        MQTTClient_destroy(&client);
        return EXIT_FAILURE;
    }

    conn_opts.MQTTVersion = MQTTVERSION_3_1_1;
    conn_opts.keepAliveInterval = 20;
    conn_opts.cleansession = 1;

    rc = MQTTClient_connect(client, &conn_opts);

    if (rc != MQTTCLIENT_SUCCESS) {
        fprintf(stderr, "[ERROR] Failed to connect, return code: %d\n", rc);
        MQTTClient_destroy(&client);
        return EXIT_FAILURE;
    }

    printf("[INFO] Connected to broker: %s\n", BROKER);

    rc = MQTTClient_subscribe(client, TOPIC, QOS);

    if (rc != MQTTCLIENT_SUCCESS) {
        fprintf(stderr, "[ERROR] Failed to subscribe, return code: %d\n", rc);
        MQTTClient_disconnect(client, TIMEOUT);
        MQTTClient_destroy(&client);
        return EXIT_FAILURE;
    }

    printf("[INFO] Subscribed to topic: %s\n", TOPIC);
    printf("[INFO] Alert monitor running. Press CTRL+C to stop.\n\n");

    while (running) {
        sleep(1);
    }

    printf("\n[INFO] Stopping alert monitor...\n");

    MQTTClient_unsubscribe(client, TOPIC);
    MQTTClient_disconnect(client, TIMEOUT);
    MQTTClient_destroy(&client);

    printf("[INFO] Disconnected cleanly.\n");

    return EXIT_SUCCESS;
}