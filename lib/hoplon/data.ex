defmodule Hoplon.Data do
  require Record

  @extract_opts [from: "src/generated/HoplonMessages.hrl"]
  # IO.inspect(Record.extract_all(@extract_opts))

  Record.defrecord(:package, :Package, Record.extract(:Package, @extract_opts))
  Record.defrecord(:audit, :Audit, Record.extract(:Audit, @extract_opts))
  Record.defrecord(:signed_audit, :SignedAudit, Record.extract(:SignedAudit, @extract_opts))
end
