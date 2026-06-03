#ifndef SUBSCRIBER
#define SUBSCRIBER

#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <signal.h>
#include <time.h>

#include "MQTTClient.h"

#define BROKER   "tcp://broker.hivemq.com:1883"
#define CLIENTID "ilaario-alert-monitor"
#define TOPIC    "unizar/eina/alerts"
#define QOS      1
#define TIMEOUT  10000L

#endif // SUBSCRIBER