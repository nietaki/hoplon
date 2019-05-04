# Directory Structure

Hoplon caches some data on the developer's disk. Here's how it organises its data:

```bash
~/.hoplon/ # can be overridden by setting HOPLON_DIR environment variable
  repos/
    <github_username>/
      <repo_one>/
        # cloned repository contents
      <repo_two>/

  env/
    default/ # "default" is the default environment name, if no other is specified
      config.exs  # contains trusted keys, and other config, like the url for the server

      my.private.pem # user's password-protected private key
      my.public.pem  # user's public key
      

      peer_keys/    # contains public keys the developer interacted with
                    # NOTE, those are not necessarily trusted keys
        <fingerprint>.public.pem
        071972badf41fcf7cedf59b2af686e6bf6492f655b616c04eb48f7d87243825a.public.pem
        89197f969fac85701a8f4b381bef20ffce2c8af382f48187b988ec13d42462ef.public.pem

      audits/ # contains previously downloaded or locally generated audits
              # just because an audit is here, it doesn't mean that it's trusted,
              # it still gets re-verified based on the trusted keys
        <package_name>/
          <package_hash>/
            <fingerprint>.audit # contains the ASN.1 encoded Hoplon Audit message
            <fingerprint>.sig   # contains the signature of the above audit message

    <environment_name>/
      # contents analogous as in env/default

```

TODO:
- a signed file containing a list of trusted fingerprints?
  - no, it would only help if you assume your filesystem is compromised
- do we want to store my.public.pem?
  - yes, so that it can be easily shared with others
- do we want to store self.fingerprint?
