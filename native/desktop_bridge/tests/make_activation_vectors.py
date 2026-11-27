"""Run with eli-sdk 1.3 or later installed:  python tests/make_activation_vectors.py tests/activation_vectors.json

Activation vectors for ELI VR's Rust reader, made by eli-sdk itself with throwaway keys, so the two
readers are tested against the same tokens. Writes tests/activation_vectors.json."""
import json, sys
from datetime import datetime, timedelta, timezone
from eli_sdk.issuing import (activated_body, certify_issuer, licence_body, new_signing_key, sign_key,
                             sign_revocations)
from eli_sdk.keys import read_key

root_private, root_public = new_signing_key()
issuer_private, issuer_public = new_signing_key()
now = datetime.now(timezone.utc).replace(microsecond=0)
cert = certify_issuer(root_private, issuer_public, issuer_id="store-test", not_before=now - timedelta(days=1),
                      not_after=now + timedelta(days=3650), products=["*"])
narrow = certify_issuer(root_private, issuer_public, issuer_id="legal-only", not_before=now - timedelta(days=1),
                        not_after=now + timedelta(days=3650), products=["legal"], may_revoke=False)
HERE, THERE = "a" * 64, "b" * 64
bought = sign_key(licence_body("vr", "pro", seats=2, activate=True, license_id="L-VR-1"), root_private,
                  public_key=root_public)
lic = read_key(bought, root_public)
here = sign_key(activated_body(lic, HERE, "A-HERE"), issuer_private, certificate=cert, public_key=root_public)
there = sign_key(activated_body(lic, THERE, "A-THERE"), issuer_private, certificate=cert, public_key=root_public)
eli_bought = sign_key(licence_body("eli", "pro", includes={"vr": 1}, activate=True, license_id="L-ELI-1"),
                      root_private, public_key=root_public)
eli_here = sign_key(activated_body(read_key(eli_bought, root_public), HERE, "A-ELI"), issuer_private,
                    certificate=cert, public_key=root_public)
released = sign_revocations(issuer_private, serial=1, activations=["A-THERE"], certificate=cert)
withdrawn = sign_revocations(root_private, serial=1, licences=["L-ELI-1"])
out = {
    "root_public_pem": root_public.decode(),
    "here": HERE, "there": THERE,
    "bought": bought, "activated_here": here, "activated_there": there,
    "eli_bought": eli_bought, "eli_activated_here": eli_here,
    "released_there": released, "withdrawn_eli": withdrawn,
}
# a key from an issuer certified for ELI Legal only is not an ELI VR key
body = licence_body("vr", "pro", license_id="L-VR-3")
body["issuer"] = narrow
raw = json.dumps(body, sort_keys=True, separators=(",", ":")).encode()
from eli_sdk._encoding import b64url_encode
from eli_sdk.issuing import load_private_key
out["vr_key_from_legal_only_issuer"] = f"ELIV3-{b64url_encode(raw)}.{b64url_encode(load_private_key(issuer_private).sign(raw))}"
json.dump(out, open(sys.argv[1], "w"), indent=1)
print("written")
