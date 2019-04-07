defmodule Hoplon.Data do
  require Record

  @extract_opts [from: "src/generated/HoplonMessages.hrl"]
  IO.inspect(Record.extract_all(@extract_opts))

  Record.defrecord(:package, :Package, Record.extract(:Package, @extract_opts))
  Record.defrecord(:audit, :Audit, Record.extract(:Audit, @extract_opts))
  Record.defrecord(:signed_audit, :SignedAudit, Record.extract(:SignedAudit, @extract_opts))

  @record_tags [:Package, :Audit, :SignedAudit]

  def encode(package) when Record.is_record(package) and elem(package, 0) in @record_tags do
    tag = elem(package, 0)
    :HoplonMessages.encode(tag, package)
  end

  def decode(message, tag) when is_binary(message) and tag in @record_tags do
    :HoplonMessages.decode(tag, message)
  end
end
