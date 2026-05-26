WALLET_FILE := .wallet

.PHONY: create-wallet get-wallet-address get-private-key

## create-wallet: generate a fresh Ethereum keypair and store it in .wallet
## Refuses to overwrite an existing wallet — delete .wallet first if you
## really want to regenerate (you will lose access to whatever was funded
## under the old key).
create-wallet:
	@if [ -f $(WALLET_FILE) ]; then \
		echo "Error: $(WALLET_FILE) already exists. Delete it first if you want to regenerate." >&2; \
		exit 1; \
	fi
	@out=$$(cast wallet new); \
	addr=$$(echo "$$out" | awk '/Address:/ {print $$2}'); \
	pk=$$(echo "$$out"  | awk '/Private key:/ {print $$3}'); \
	if [ -z "$$addr" ] || [ -z "$$pk" ]; then \
		echo "Error: failed to parse cast wallet new output:" >&2; \
		echo "$$out" >&2; \
		exit 1; \
	fi; \
	printf 'ADDRESS=%s\nPRIVATE_KEY=%s\n' "$$addr" "$$pk" > $(WALLET_FILE); \
	chmod 600 $(WALLET_FILE); \
	echo "Wallet saved to $(WALLET_FILE)"; \
	echo "Address: $$addr"

## get-wallet-address: print the saved wallet's 0x address to stdout
get-wallet-address:
	@test -f $(WALLET_FILE) || { echo "Error: no wallet. Run 'make create-wallet' first." >&2; exit 1; }
	@grep '^ADDRESS=' $(WALLET_FILE) | cut -d= -f2-

## get-private-key: print the saved wallet's private key to stdout
get-private-key:
	@test -f $(WALLET_FILE) || { echo "Error: no wallet. Run 'make create-wallet' first." >&2; exit 1; }
	@grep '^PRIVATE_KEY=' $(WALLET_FILE) | cut -d= -f2-

get-rpc-url:
	@echo "SEPOLIA_RPC_URL=https://ethereum-sepolia-rpc.publicnode.com"
	@echo "Or any rpc-url from here: https://chainlist.org/chain/11155111"