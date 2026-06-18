# Replicação de Dados em Ambientes Distribuídos

Esse repositório é parte de um dos experimentos realizados para minha pseudo-tese em [castro-research/asyncronous-replication-multi-tenant-database](https://github.com/castro-research/asyncronous-replication-multi-tenant-database).

Nesta implementação, o foco é replicar dados de um banco de dados central (DB0) para bancos de dados locais (DB1, DB2, DB3) em um ambiente multi-tenant. O objetivo é garantir que as tabelas de configuração do sistema sejam replicadas corretamente para cada tenant, permitindo que o sistema funcione de maneira distribuída e independente.

Ao contrário do broker, eu não uso Kafka ou RabbitMQ, mas sim o Pub/Sub nativo do PostgreSQL, que é uma funcionalidade de mensagens assíncronas que permite que os bancos de dados se comuniquem entre si.

# Pontos pendentes

- [ ] Replicação de exclusão de dados
- [ ] Quando um dos bancos tem dependências, como chaves estrangeiras, o que fazer?
- [ ] Um dos bancos está offline, como lidar com isso? E quando voltar online, como sincronizar os dados?