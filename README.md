# Arbol-dApp

Arbol-dApp Monorepo.

## Web App (off-chain)

The frontend is bootstrapped with [Create Eth App](https://github.com/paulrberg/create-eth-app) and hosted on a Heroku server. It is a work in progress and currently provides interfaces for the Dallas Blizzard Protection contract. It will contain interfaces for all deployed contracts.

## Chainlink Node (bridge)

A Docker Compose project to launch an Arbol-Chainlink node on a new AWS EC2 (Amazon Linux 2) instance. The project deploys containers for
a [Chainlink](https://github.com/smartcontractkit/chainlink) node for fulfilling smart contract oracle requests, an [IPFS](https://github.com/ipfs/go-ipfs) daemon for retrieving Arbol weather data and listening to IPFS-HTTP requests, and a Gunicorn server running a Chainlink external adapter for serving requests using the [dClimate Python Client](https://github.com/dClimate/dWeather-Python-Client) and computing payout evaluations on retrieved data.

To launch a new node with new or imported credentials and contract data, run the following:

```
sudo yum install -y git
git clone --recurse-submodules https://github.com/dmp267/Arbol-dApp.git
bash Arbol-dApp/chainlink_node/scripts/setup-AWS.sh
exit

# forward credentials from Arbol-dApp repo on local machine
bash chainlink_node/scripts/send-secrets.sh

# log back in and set sensitive data
bash Arbol-dApp/chainlink_node/scripts/receive-secrets.sh
cd Arbol-dApp/chainlink_node
docker compose up --build
```

The Chainlink Node GUI can be accessed at `https://localhost:6689`; if SSH tunneling into EC2 instance on a VPC add `-L 6689:localhost:6689` to forward to your local machine.

The IPFS web UI can be accessed at `http://localhost:5001/webui`; if SSH tunneling into EC2 instance on a VPC add `-L 5001:localhost:5001` to forward to your local machine.

## Smart Contracts (on-chain)

This directory holds smart contract source for Arbol derivative deals, Hardhat deployment, verification, and evaluation scripts, Chainlink oracle job definitions, and contract deployment records.

To deploy, verify, and test smart contracts located in `smart_contracts/hardhat/contracts`, first make sure Hardhat
is installed locally, then run the following:

```
# from Arbol-dApp
cd smart_contracts/hardhat
npx hardhat run scripts/deploy-all.js # or replace with specific deployment script
npx hardhat run scripts/verify-deployments.js
npx hardhat run scripts/evaluate-deployments.js
```

Deployment details can be viewed in `smart_contracts/hardhat/logs`. Depending on the contract, evaluation may fail if certain conditions are not met (for example, for all contracts, LINK token provider must first approve derivativeProvider contract to move funds for oracle requests).
