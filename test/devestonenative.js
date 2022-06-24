const DevestOneNative = artifacts.require("DevestOneNative");
const DevestOne = artifacts.require("DevestOne");
const ERC20 = artifacts.require("ERC20PresetFixedSupply");

/*
contract('DevestOneNative', (accounts) => {

    it('should put 1000000 Token in the first account', async () => {
        const ERC20TokenInstance = await ERC20.deployed();
        const balance = await ERC20TokenInstance.balanceOf.call(accounts[0]);

        const balanceAccount = await web3.eth.getBalance(accounts[0]);

        assert.isTrue(balance.valueOf() > 0, "To less token");
        assert.isTrue(Number(balanceAccount) > 0)
    });

    it('should transfer some ETH Token to all traders', async () => {
        const erc20Token = await ERC20.deployed();

        // Setup account.
        const account = accounts[0];

        // Make transaction from first account to second.
        for (let i = 2; i < 10; i++) {
            const amount = 40000000000;
            await erc20Token.transfer(accounts[i], amount, { from: account });
        }

        // Get balances of first and second account after the transactions.
        const accountOneEndingBalance = (await erc20Token.balanceOf.call(account)).toNumber();

        // send back
        assert.equal(accountOneEndingBalance, 680000000000, "Failed to transfer funds");
    });

    it('should Setup Tangible', async () => {
        const devestOne = await DevestOneNative.deployed();

        await devestOne.initialize(3000000000, 10, false, { from: accounts[0] });
        await devestOne.setTangible(accounts[1], { from: accounts[0] });

        const pricePerUnit = (await devestOne.getPrice.call()).toNumber();
        assert.equal(pricePerUnit, 3000000000 / 100, "Invalid price on initialized tangible");
    })

    it('Add more buy orders', async () => {
        const erc20Token = await ERC20.deployed();
        const devestOne = await DevestOneNative.deployed();

        const price = (await devestOne.getPrice.call()).toNumber();

        // submit bid
        await createBid(20, price, accounts[4]);
        await createBid(10, price * 1.5, accounts[5]);
        await createBid(20, price * 2, accounts[6]);
        await createBid(20, price * 0.5, accounts[7]);

        let totalEscrow = 20 * price + (10 * price * 1.5) + (20 * price * 2) + (20 * price * 0.5);
        totalEscrow += (totalEscrow * 10) / 100;

        // tangible funds should increase
        const fundsTangible = (await erc20Token.balanceOf.call(devestOne.address)).toNumber();
        assert.equal(fundsTangible, totalEscrow, "Invalid funds submitting buy orders");

        const orders = await devestOne.getOrders.call();
        assert.equal(orders.length, 4, "Order not stored");
        assert.equal(orders[0].price, 30000000, "Order has invalid price");
    })

    it('Accept bids', async () => {
        const erc20Token = await ERC20.deployed();
        const devestOne = await DevestOneNative.deployed();

        let fundsTangible = (await erc20Token.balanceOf.call(accounts[1])).toNumber();
        let fundsOwner = (await erc20Token.balanceOf.call(accounts[0])).toNumber();
        let earningOnwer = 0;

        // fetch offers
        const offers = await devestOne.getOrders.call();

        // --- accept #1

        await devestOne.accept(offers[0].from, 20, { from: accounts[0], value: 10000000 });
        let balanceBefore = await web3.eth.getBalance(devestOne.address);
        fundsTangible = (await erc20Token.balanceOf.call(accounts[1])).toNumber();
        earningOnwer += ((await erc20Token.balanceOf.call(accounts[0])).toNumber() - fundsOwner);
        fundsOwner = (await erc20Token.balanceOf.call(accounts[0])).toNumber();
        assert.equal(earningOnwer, 600000000, "Invalid tax paid to player");

        // --- accept #2

        await devestOne.accept(offers[1].from, 10, { from: accounts[0], value: 10000000 });
        fundsTangible = (await erc20Token.balanceOf.call(accounts[1])).toNumber();
        earningOnwer += ((await erc20Token.balanceOf.call(accounts[0])).toNumber() - fundsOwner);
        fundsOwner = (await erc20Token.balanceOf.call(accounts[0])).toNumber();
        assert.equal(earningOnwer, 1050000000, "Invalid tax paid to player");

        // --- accept #3

        await devestOne.accept(offers[2].from, 10, { from: accounts[0], value: 10000000 });

        fundsTangible = (await erc20Token.balanceOf.call(accounts[1])).toNumber();
        earningOnwer += ((await erc20Token.balanceOf.call(accounts[0])).toNumber() - fundsOwner);
        fundsOwner = (await erc20Token.balanceOf.call(accounts[0])).toNumber();
        assert.equal(earningOnwer, 1650000000, "Invalid funds on player after bid");

        // --- leftover escrow

        fundsTangible = (await erc20Token.balanceOf.call(accounts[0])).toNumber();
        const total = 681650000000;
        assert.equal(fundsTangible, total, "Invalid funds on tangible after accept");

        // --- all shareholders
        const shareholders = await devestOne.getShareholders.call();
        assert.equal(shareholders[0], accounts[0], "Invalid shares");
        assert.equal((await devestOne.getShares.call(accounts[0])).toNumber(), 60, "Invalid shares");

        assert.equal(shareholders[1], accounts[4], "Invalid shares");
        assert.equal((await devestOne.getShares.call(accounts[4])).toNumber(), 20, "Invalid shares");

        assert.equal(shareholders[2], accounts[5], "Invalid shares");
        assert.equal((await devestOne.getShares.call(accounts[5])).toNumber(), 10, "Invalid shares");

        assert.equal(shareholders[3], accounts[6], "Invalid shares");
        assert.equal((await devestOne.getShares.call(accounts[6])).toNumber(), 10, "Invalid shares");
    });

    it('Pay Native Dividends', async () => {
        const erc20Token = await ERC20.deployed();
        const devestOne = await DevestOneNative.deployed();

        // collect current funds of shareholders before dividends are paid
        const shareholders = await devestOne.getShareholders.call();
        const shareHoldersFunds = [];
        for(let shareholder of shareholders){
            shareHoldersFunds.push({
                address: shareholder,
                balance: parseInt(await web3.eth.getBalance(shareholder)),
                shares: (await devestOne.getShares.call(shareholder)).toNumber(),
            });
        }

        let balanceBefore = parseInt(await web3.eth.getBalance(devestOne.address));

        // pay
        await devestOne.payNative({ from: accounts[1], value: 200000000 });

        // check balance
        let balanceAfter = parseInt(await web3.eth.getBalance(devestOne.address));
        assert.equal(balanceBefore + 180000000, balanceAfter, "Invalid balance on Tangible");

        // disburse
        await devestOne.disburseNative({ from: accounts[1] });

        // check dividends
        let split = (200000000 * 0.9) + 30000000; // remove tax
        for(let shareholder of shareHoldersFunds){
            const after = parseInt(await web3.eth.getBalance(shareholder.address));
            const d = (shareholder.shares * split) / 100;
            console.log(after - shareholder.balance, d);
            assert.equal((after - shareholder.balance) > (d * 0.95), true, "Invalid dividends disbursed");
        }
    });

});

const createBid = async (percent, price, address) => {
    const erc20Token = await ERC20.deployed();
    const devestOneNative = await DevestOneNative.deployed();

    // submit bid
    let escrow = price * percent;
    escrow = escrow + (escrow * 0.1)
    await erc20Token.approve(devestOneNative.address, escrow, { from: address });
    await devestOneNative.bid(price, percent, {from: address});
}
*/
