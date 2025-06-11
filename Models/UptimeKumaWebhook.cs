namespace IISAppPoolRecycler.Models
{
    public class UptimeKumaWebhook
    {
        public string? HeartBeat { get; set; }
        public Monitor? Monitor { get; set; }
        public string? Msg { get; set; }
    }

    public class Monitor
    {
        public int Id { get; set; }
        public string? Name { get; set; }
        public string? Url { get; set; }
        public string? Hostname { get; set; }
        public int Port { get; set; }
        public int MaxRedirects { get; set; }
        public string? MaxRetries { get; set; }
        public string? Weight { get; set; }
        public bool Active { get; set; }
        public string? Type { get; set; }
        public int Interval { get; set; }
        public int RetryInterval { get; set; }
        public string? Keyword { get; set; }
        public string? InvertKeyword { get; set; }
        public string? ExpiryNotification { get; set; }
        public string? IgnoreTLS { get; set; }
        public string? UpsideDown { get; set; }
        public int MaxTimeout { get; set; }
        public string? AcceptedStatusCodes { get; set; }
        public string? DNS_ResolveServer { get; set; }
        public string? DNS_ResolveType { get; set; }
        public string? MqttUsername { get; set; }
        public string? MqttPassword { get; set; }
        public string? MqttTopic { get; set; }
        public string? MqttSuccessMessage { get; set; }
        public string? DatabaseConnectionString { get; set; }
        public string? DatabaseQuery { get; set; }
        public string? AuthMethod { get; set; }
        public string? AuthWorkstation { get; set; }
        public string? AuthDomain { get; set; }
        public string? TLSCa { get; set; }
        public string? TLSCert { get; set; }
        public string? TLSKey { get; set; }
        public string? TLSCaFilename { get; set; }
        public string? TLSCertFilename { get; set; }
        public string? TLSKeyFilename { get; set; }
        public string? GrpcUrl { get; set; }
        public string? GrpcProtobuf { get; set; }
        public string? GrpcMethod { get; set; }
        public string? GrpcServiceName { get; set; }
        public string? GrpcEnableTLS { get; set; }
        public string? RadiusUsername { get; set; }
        public string? RadiusPassword { get; set; }
        public string? RadiusSecret { get; set; }
        public string? RadiusCalledStationId { get; set; }
        public string? RadiusCallingStationId { get; set; }
        public string? Game { get; set; }
        public string? Gamedig_type { get; set; }
        public string? Jsonpath { get; set; }
        public string? ExpectedValue { get; set; }
        public string? KafkaProducerTopic { get; set; }
        public string? KafkaProducerBrokers { get; set; }
        public string? KafkaProducerAllowAutoTopicCreation { get; set; }
        public string? KafkaProducerMessage { get; set; }
        public string? IncludeInternalIP { get; set; }
        public DateTime CreatedDate { get; set; }
        public int Tags { get; set; }
    }

    public class HeartBeat
    {
        public int MonitorID { get; set; }
        public int Status { get; set; }
        public DateTime Time { get; set; }
        public string? Msg { get; set; }
        public bool Important { get; set; }
        public int Duration { get; set; }
    }
}
