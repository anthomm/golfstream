Task analysis
- I haven't used Kafka before, isn't this a streaming service rather than a message broker? I need to find out how it handles messages and if this is what the task means by persisting. To me that sounds odd as I would consider persistence something like a DB or a cache.
- The focus in Kafka is on events, not messages, but this isn't to say that they are data-less. They carry semantics beyond merely notifying that an event has occurred, so I should be careful not to make a mental model comparing them to Azure Event Grid's patterns.
- Documentation says that Kafka's Data Lifespan is durable, allowing data to persist on disk for an arbitrary amount of time. Going forwards, my assumption will be that this is sufficient as far as persistence goes wrt the task.
- Consumers track their own consumption instead of relying on smart brokers/subscriptions. Since I don't seem to be consuming Kafka, but instead placing events into the stream as a producer, then I suppose I won't have to account for implementing a smart client responsible for tracking offsets.
- Kafka seems to be comparable to K8s regarding how to distribute its concepts: Partition = Pod, Topic = Namespace, Broker = Node. Just keep in mind that Kafka is stateful while k8s is ephemeral.
- OLAP vs OLTP: Do I have to consider the schema of the DTOs and possible business rules of the domain model? Is this supposed to be used for real time analytics or dumped into a data lake or warehouse?
- REST / CQRS: The task seems to lend itself towards a simple command that allows us to separate write events that need to be persisted via Kafka to a DB from the same service that would query for reading the information. 
- Understanding consistency across the API and system at large, eg: adding an event to Kafka wouldn't mean that its data would be immediately available to fetching from the DB if we were to fetch it from the API immediately after producing the event.
- Is this really an API as much as a worker? I think that things like 3-layer arch makes sense for an API that might share code horizontally across resources, but for a single producer endpoint this might be overkill.


Implementation plan
API using Golang.
1. Simple ingestion layer for for a CQRS command that will produce events.
	1. This means a Vertical Slice Architecture.
	2. The input is arbitrary JSON, embed this JSON as the value of the kafka event.
2. Logging
3. Testing Interfaces with mocking
4. Packages to use. Gin Gonic, Zap, franz-go, validators?

Implementation thoughts
- ~~Use pointers to avoid defensive copies of the JSON payload. For an ingestion layer the throughput is expected to be large.~~
	- json.RawMessage is defined as type RawMessage []byte. A slice in Go is already a three-word header (pointer + length + capacity). Copying a Command by value copies only that header, not the underlying byte data. The large JSON payload is on the heap and is never duplicated; both the caller and callee point to the same backing array.
- Not familiar with this kafka client, so I'll have to rely on Copilot for wiring up the producer implementation.
- Currently passing logger as a struct field. This is nice for mocking tests, but I would sooner leave it as a global singleton. Feeling cute, might fix later. Maybe.
- I am getting 200 OKs from posting jsons to the producer, but I would like to actually view them in Kafka without setting up a consumer. Is that possible?
- I will try to extend the docker-compose.yaml to include a UI client that will connect to the stream.
- Success! I added provectuslabs/kafka-ui to the docker-compose and forwarded it to localhost:8888. I can see that messages I send using postman with randomized keys and containing randomized values are placed on the local-cluster > Topics > hc > Messages.
- I did a stress test using Postman's collection runner with 10k iteration with 0 ms delay. The stress test succeeded with every call being around 5ms each. I verified in the UI client that all messages were received and persisted. Wow. Kafka is pretty neat. RIP to the API's std out for info severity logging, though. If volumes are this high I should probably reconsider logging every request hitting the ingestion layer.
- Added an AI-generated cURL script to /scripts for testing outside postman.
  - Run it using "COUNT=5 DELAY=0.2 ./scripts/post_events.sh"

Future Improvements
- Consider Authn/Authz
- Consider full observability using OpenTelemetry for metrics and traces along with logs.
- Consider gRPC for efficient serialization wrt to high volume.
- Consider compression on the producer side.
- Consider OpenAPI spec, especially if this API is supposed to hold queries as well as commands.
- Consider Dockerfile.
- Consider CICD / Github Workflows and IaC like Terraform if each service is responsible for provisioning for itself.
- Governance requirements, third party storage of ID-able information, Data Loss Prevention since we're possibly processing PII?
- Consider Idempotency.
- Consider adding tracking ID and code `202 Accepted` for ingestion commands.
- Consider adding Makefile for common tasks like building, testing, running the API and deployment or IaC.