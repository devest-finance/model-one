const ERC20PresetFixedSupply = artifacts.require("ERC20PresetFixedSupply");
const DevestOne = artifacts.require("DevestOne");
const DevestOneNative = artifacts.require("DevestOneNative");

module.exports = function(deployer) {
  if (deployer.network === 'development') {
      deployer.deploy(ERC20PresetFixedSupply, "ERC20 Token", "TKO", 1000000000000, "0xECF5A576A949aEE5915Afb60E0e62D09825Cd61B")
        .then(() => ERC20PresetFixedSupply.deployed())
        .then(async _instance => {
            await deployer.deploy(DevestOne, _instance.address, "Example", "EXP", "0xECF5A576A949aEE5915Afb60E0e62D09825Cd61B");
            await deployer.deploy(DevestOneNative, _instance.address, "ExampleNative", "EXP", "0xECF5A576A949aEE5915Afb60E0e62D09825Cd61B");
        }
      )
  } else {
    deployer.deploy(DevestOne);
  }
};
