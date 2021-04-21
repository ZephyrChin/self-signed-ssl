## Example:
```
auto.sh -h # or --help
```
```
auto.sh --ecc --subj="/C=US/ST=California/L=SanFrancisco/O=github/CN=github.com"
```
Note: This script generates a legacy X.509 cert(version 1), you'd better not use it. I had refered to an old article(about how to create self-signed certificate), but at that time i was not aware of this.
