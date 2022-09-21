const DevestOne = artifacts.require("DevestOne");
const DevestOneNative = artifacts.require("DevestOneNative");
const DevestFactory = artifacts.require("DevestFactory");
const ERC20PresetFixedSupply = artifacts.require("ERC20PresetFixedSupply");

module.exports = function(deployer) {
  if (deployer.network === 'development') {
      deployer.deploy(DevestFactory)
          .then(() => DevestFactory.deployed())
          .then(() => deployer.deploy(ERC20PresetFixedSupply, "ERC20 Token", "TKO", 1000000000000, "0xECF5A576A949aEE5915Afb60E0e62D09825Cd61B"))
            .then(() => ERC20PresetFixedSupply.deployed())
            .then(async _instance => {
                //await deployer.deploy(DevestOne, _instance.address, "Example", "EXP", "0xECF5A576A949aEE5915Afb60E0e62D09825Cd61B");
                //await deployer.deploy(DevestOneNative, _instance.address, "ExampleNative", "EXP", "0xECF5A576A949aEE5915Afb60E0e62D09825Cd61B");
            }
      )
  } else if (deployer.network === 'testnet') {
      // used USDT testnet tokens
      // 0xbBc2BFe41Ed62D40ec8f646b45017342A0d1837f -- first one
      // deployer.deploy(DevestOneNative, "0x337610d27c682E347C9cD60BD4b3b107C9d34dDd", "DeVest|Finance", "DEV", "0x99FdDe4743909706f69B7d4D77D2C2e20b9B47B4");
      // 0x7b9180829aa12f45d706a79025b61eC3DD201AE9 -- deployer firstr
      deployer.deploy(DevestFactory);
  } else {

  }
};
