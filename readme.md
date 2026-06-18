# Replicação de Dados em Ambientes Distribuídos

Esse repositório é parte de um dos experimentos realizados para minha pseudo-tese em [castro-research/asyncronous-replication-multi-tenant-database](https://github.com/castro-research/asyncronous-replication-multi-tenant-database).

Nesta implementação, o foco é replicar dados de um banco de dados central (DB0) para bancos de dados locais (DB1, DB2, DB3) em um ambiente multi-tenant. O objetivo é garantir que as tabelas de configuração do sistema sejam replicadas corretamente para cada tenant, permitindo que o sistema funcione de maneira distribuída e independente.

Ao contrário do broker, eu não uso Kafka ou RabbitMQ, mas sim o Pub/Sub nativo do PostgreSQL, que é uma funcionalidade de mensagens assíncronas que permite que os bancos de dados se comuniquem entre si.

# Pontos pendentes

- [ ] Replicação de exclusão de dados
- [ ] Quando um dos bancos tem dependências, como chaves estrangeiras, o que fazer?
- [ ] Um dos bancos está offline, como lidar com isso? E quando voltar online, como sincronizar os dados?


## Referências

["O processo de aplicação no banco de dados subscriber sempre é executado com session_replication_role definido como replica. Isso significa que, por padrão, triggers e rules não serão disparados em um subscriber."](https://www.postgresql.org/docs/current/logical-replication-architecture.html)

["Como as chaves estrangeiras são implementadas como triggers, definir session_replication_role como replica também desabilita todas as verificações de chaves estrangeiras... As restrições de chave estrangeira não são aplicadas no processo de replicação — o que for bem-sucedido no lado do provedor será aplicado ao subscriber, mesmo que a FOREIGN KEY fosse violada."](https://www.postgresql.org/docs/current/logical-replication-architecture.html)

["A ordem dessas alterações pode entrar em conflito com as restrições de chave estrangeira no subscriber, o que pode acontecer se você modificar ambas as tabelas em uma única instrução no publisher ou se adiar a verificação de chave estrangeira até o final da transação."](https://www.postgresql.org/docs/current/logical-replication-architecture.html)

["PostgreSQL Logical Replication and Foreign Key Constraints"](https://deepbluecap.com/postgresql-logical-replication-and-foreign-key-constraints/)

[Linhas orfãs e chaves estrangeiras quebradas no PostgreSQL](https://www.cybertec-postgresql.com/en/broken-foreign-keys-postgresql/)


