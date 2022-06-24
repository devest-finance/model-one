const DevestFactory = artifacts.require("DevestFactory");
const DevestOne = artifacts.require("DevestOne");

contract("DeVestFactory", function (accounts) {

    describe.only("deploy contract", async () => {

        let deployer;
        beforeEach(async () => {
            deployer = await DevestFactory.deployed();
        });

        it("should create new children", async () => {
            const gasUsed = [];

            for(let i=0;i<4;i++){
                const res = await deployer.issue('0xECF5A576A949aEE5915Afb60E0e62D09825Cd61B', "TST Example", "TKO", { from: accounts[0] });
                gasUsed.push(res.receipt.gasUsed);
            }

            const history = await deployer.history.call(0);

            assert.equal(!history[3].startsWith("0x00000000"), true, "TST are not issued");
            assert.equal(history[4].startsWith("0x00000000"), true, "Addresses should be free");
        });

        it("Test tangible", async () => {
            const history = await deployer.history.call(0);
            const devestOne = await DevestOne.at(history[0]);

            await devestOne.initialize(3000000000, 10, true, { from: accounts[0] });
            await devestOne.setTangible(accounts[1], { from: accounts[0] });

            const pricePerUnit = (await devestOne.price.call()).toNumber();
            assert.equal(pricePerUnit, 3000000000 / 100, "Invalid price on initialized tangible");
        })


    });
});
