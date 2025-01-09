-include .env

.PHONY: all test clean deploy fund help install snapshot format anvil zktest

DEFAULT_ANVIL_KEY := 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

all: clean remove install update build

# Clean the repo
clean  :; forge clean

# Remove modules
remove :; rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules && git add . && git commit -m "modules"

install :; forge install cyfrin/foundry-devops@0.2.2 --no-commit && forge install smartcontractkit/chainlink-brownie-contracts@1.1.1 --no-commit && forge install foundry-rs/forge-std@v1.8.2 --no-commit

# Update Dependencies
update:; forge update

build:; forge build

test :; forge test

snapshot :; forge snapshot

format :; forge fmt

anvil :; anvil -m 'test test test test test test test test test test test junk' --steps-tracing --block-time 1

deploy:
	@forge script script/DeployDigitalP2P.s.sol:DeployDigitalP2P $(NETWORK_ARGS)

NETWORK_ARGS := --rpc-url http://localhost:8545 --private-key $(DEFAULT_ANVIL_KEY) --broadcast

ifeq ($(findstring --network polygon,$(ARGS)),--network polygon)
	NETWORK_ARGS := --rpc-url $(POLIGON_RPC_URL) --account $(POLIGON_ACCOUNT_ADDRESS) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv
endif

ifeq ($(findstring --network sepolia,$(ARGS)),--network sepolia)
	NETWORK_ARGS := --rpc-url $(SEPOLIA_RPC_URL) --account $(SEPOLIA_ACCOUNT_ADDRESS) --broadcast --verify --etherscan-api-key $(SEPOLIA_ETHERSCAN_API_KEY) -vvvv
endif

deploy-polygon:
	@forge format
	@forge clean
	@forge test
	@forge script script/DeployDigitalP2P.s.sol:DeployDigitalP2P $(NETWORK_ARGS)


#SENDER_ADDRESS := <sender's address>
SENDER_ADDRESS := 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266

processOrder:
	@forge script script/Interactions.s.sol:DigitalP2PProcessOrder --sender $(SENDER_ADDRESS) $(NETWORK_ARGS)

releaseOrder:
	@forge script script/Interactions.s.sol:DigitalP2PReleaseOrder --sender $(SENDER_ADDRESS) $(NETWORK_ARGS)
