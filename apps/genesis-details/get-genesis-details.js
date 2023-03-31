var fs = require('fs');

async function main() {
  var types = await import("@chainsafe/lodestar-types");
  var BeaconState = types.ssz.bellatrix.BeaconState;

  // read genesis.ssz
  var binary = fs.readFileSync(process.argv[process.argv.length - 1]);
  var beaconState = BeaconState.deserialize(binary)

  console.log("genesisTime: " + beaconState.genesisTime);
  console.log("genesisValidatorsRoot: 0x" + beaconState.genesisValidatorsRoot.toString('hex'));
}

main();
