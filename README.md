# DecentralizedEXchange

Exchange consists of 3 contracts and SafeMath library.

### Master-contract
Is throwing events and contains orders mapping and supported tokens mapping.
Places new BID or ASK contracts.

### Bid
A single BID contract.
BID contract is holding Ether and is buying tokens.
Trade is triggered when token transaction to BID contract occurs.
Only owner (BID placer) or master (an exchange contract) can send more Ether intor BID contract.

### Ask
A single ASK contract.
ASK contract is holding tokens and is selling them instantly when Ether transaction to ASK contract occurs.
Only owner (ASK placer) or master (an exchange contract) can transfer tokens (only tokens that are traded on ASK contract market) to ASK contract.
