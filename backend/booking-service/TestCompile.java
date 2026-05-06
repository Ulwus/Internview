import org.springframework.kafka.test.utils.KafkaTestUtils;
import org.springframework.kafka.test.EmbeddedKafkaBroker;
public class TestCompile {
    public void test(EmbeddedKafkaBroker broker) {
        KafkaTestUtils.consumerProps("group", "true", broker.getBrokersAsString());
    }
}
