const ModelOneFactory = artifacts.require("ModelOneFactory");
const ModelTwoFactory = artifacts.require("ModelTwoFactory");
const ERC20PresetFixedSupply = artifacts.require("ERC20PresetFixedSupply");
const ModelOne = artifacts.require("ModelOne");

module.exports = function(deployer) {
  if (deployer.network === 'development') {
      deployer.deploy(ModelOneFactory)
          .then(() => deployer.deploy(ModelTwoFactory))
          .then(() => deployer.deploy(ERC20PresetFixedSupply, "ERC20 Token", "TKO", 1000000000000, "0xECF5A576A949aEE5915Afb60E0e62D09825Cd61B"))
            .then(() => ERC20PresetFixedSupply.deployed())
            .then(async _instance => {})
            .then(() => ModelOneFactory.deployed())
            .then(async _instance => {
                const devestDAOImp = await _instance.issue("0x0000000000000000000000000000000000000000", "DeVest DAO", "DeVest DAO");
                await _instance.setRoot(devestDAOImp.logs[0].args[1], { from: "0xECF5A576A949aEE5915Afb60E0e62D09825Cd61B" });
                await _instance.setFee(100000000);
                const devestDAO = await ModelOne.at(devestDAOImp.logs[0].args[1]);
                await devestDAO.initialize(1000000000, 10, 0, { from: "0xECF5A576A949aEE5915Afb60E0e62D09825Cd61B" });
            }
      )
  } else if (deployer.network === 'alchemy') {
      //deployer.deploy(ModelOneFactory).then(() => ModelOneFactory.deployed())
      deployer.deploy(ModelTwoFactory).then(() => ModelTwoFactory.deployed())
          //.then(() => deployer.deploy(ExampleToken, "DeVest Token BNB", "TKOBNB", 10000000000000, "0x714eeEF246599733f2c7a4Cb2D9D4c29567a4239"))
          //.then(() => ExampleToken.deployed())
  } else if(deployer.network == "testnet") {
      deployer.deploy(ModelOneFactory)
          .then(() => deployer.deploy(ModelTwoFactory))
          .then(async _instance => {
                  const devestDAOImp = await _instance.issue("0x0000000000000000000000000000000000000000", "DeVest DAO 2.0", "DeVest DAO 2.0");
                  await _instance.setRoot(devestDAOImp.logs[0].args[1]);
                  await _instance.setFee(100000000);
                  const devestDAO = await ModelOne.at(devestDAOImp.logs[0].args[1]);
                  await devestDAO.initialize(1000000000, 10, 0);
              }
          )
  }
};
