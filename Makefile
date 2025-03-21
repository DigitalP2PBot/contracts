ENV ?= dev

# Include the appropriate .env file
include .env.$(ENV)
export $(shell sed 's/=.*//' .env.$(ENV))

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


NETWORK_ARGS := --rpc-url http://localhost:8545 --private-key $(DEFAULT_ANVIL_KEY) --broadcast

ifeq ($(findstring --network polygon,$(ARGS)),--network polygon)
	NETWORK_ARGS := --rpc-url $(POLYGON_RPC_URL) --account $(POLYGON_ACCOUNT_ADDRESS) --broadcast --verify --etherscan-api-key $(POLYGON_ETHERSCAN_API_KEY) -vvvv
endif

ifeq ($(findstring --network polygon-prod,$(ARGS)),--network polygon-prod)
	NETWORK_ARGS := --rpc-url $(POLYGON_RPC_URL)  --broadcast -t --verify --etherscan-api-key $(POLYGON_ETHERSCAN_API_KEY) -vvvv
endif

ifeq ($(findstring --network polygon-prod-command,$(ARGS)),--network polygon-prod-command)
	NETWORK_ARGS := --rpc-url $(POLYGON_RPC_URL)  --broadcast   -vvvv
endif

ifeq ($(findstring --network sepolia,$(ARGS)),--network sepolia)
	NETWORK_ARGS := --rpc-url $(SEPOLIA_RPC_URL) --account $(SEPOLIA_ACCOUNT_ADDRESS) --broadcast --verify --etherscan-api-key $(SEPOLIA_ETHERSCAN_API_KEY) -vvvv
endif

deploy:
	echo "Environment: $(ENV)"
	echo "Network Args: $(NETWORK_ARGS)"
	@forge fmt
	@forge clean
	@forge test
	@forge script script/DeployDigitalP2P.s.sol:DeployDigitalP2P $(NETWORK_ARGS)


#SENDER_ADDRESS := <sender's address>
SENDER_ADDRESS := 0xf56ad38118da19E864552d7e73bf4A0067818cbA

processOrder:
	@forge script script/Interactions.s.sol:DigitalP2PProcessOrder --sender $(SENDER_ADDRESS) $(NETWORK_ARGS)

releaseOrder:
	@forge script script/Interactions.s.sol:DigitalP2PReleaseOrder --sender $(SENDER_ADDRESS) $(NETWORK_ARGS)

withDraw:
	@forge script script/Interactions.s.sol:DigitalP2PWithDraw --sender $(SENDER_ADDRESS) $(NETWORK_ARGS)

withDrawToken:
	echo "Network Args: $(NETWORK_ARGS)"
	@forge clean
	@forge script script/Interactions.s.sol:DigitalP2PWithDrawToken \
		--sender $(SENDER_ADDRESS)  $(NETWORK_ARGS) \
		--sig "run(address,uint256,address)" \
		0x14d5d32bccdaa481e41868206c96fd97f49dc7dc 1000000 0xc2132D05D31c914a87C6611C10748AEb04B58e8F \
