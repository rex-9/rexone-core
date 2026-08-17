module MessageService
  class Log < Base
    OCCURRENCE_RECORDED = "log.clients.occurrence_recorded"
    CREATED = "log.clients.created"
    CREATE_FAILED = "log.clients.create_failed"
    FETCHED = "log.clients.fetched"
    FETCHED_ONE = "log.clients.fetched_one"
    RESOLVED = "log.clients.resolved"
    UNRESOLVED = "log.clients.unresolved"
    DELETED = "log.clients.deleted"
  end
end
