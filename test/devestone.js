const DevestOne = artifacts.require("DevestOne");
const ERC20Token = artifacts.require("ERC20Token");
const assert = require("chai").assert;

contract('DevestOne', (accounts) => {

    it('should put 1000000 Token in the first account', async () => {
        const ERC20TokenInstance = await ERC20Token.deployed();
        const balance = await ERC20TokenInstance.balanceOf.call(accounts[0]);

        const balanceAccount = await web3.eth.getBalance(accounts[0]);

        assert.isTrue(balance.valueOf() > 0, "To less token");
        assert.isTrue(Number(balanceAccount) > 0)
    });

    it('should transfer some ETH Token to all traders', async () => {
        const erc20Token = await ERC20Token.deployed();

        // Setup account.
        const account = accounts[0];

        // Make transaction from first account to second.
        for(let i=2; i<10; i++) {
            const amount = 40000000000;
            await erc20Token.transfer(accounts[i], amount, {from: account});
        }

        // Get balances of first and second account after the transactions.
        const accountOneEndingBalance = (await erc20Token.balanceOf.call(account)).toNumber();

        // send back
        assert.equal(accountOneEndingBalance, 680000000000, "Failed to transfer funds");
    });

    it('should Setup Tangible', async () => {
        const erc20Token = await ERC20Token.deployed();
        const devestOne = await DevestOne.deployed();

        const erc20ApproveResponse = await erc20Token.approve(devestOne.address, 3000000000, { from: accounts[0] });
        assert.exists(erc20ApproveResponse.tx);

        const setTangibleRes = await devestOne.setTangible(accounts[1], {from : accounts[0]} );
        assert.exists(setTangibleRes.tx);

        const initializeRes = await devestOne.initialize(3000000000, { from: accounts[0] });
        assert.exists(initializeRes.tx);

        const pricePerUnit = (await devestOne.getPrice.call()).toNumber();
        const fundsTangible = (await erc20Token.balanceOf.call(devestOne.address)).toNumber();

        assert.equal(pricePerUnit, 30000000/100, "Invalid price on initialized tangible");
        assert.equal(fundsTangible, 3000000000, "Invalid funds on initialized tangible");
    })

    it('Submit Buy Orders', async () => {
        const erc20Token = await ERC20Token.deployed();
        const devestOne = await DevestOne.deployed();

        // submit bid
        const escrow = 1500000000 + (1500000000 * 0.1);
        await erc20Token.approve(devestOne.address, escrow, { from: accounts[2] });
        await devestOne.bid(30000000, 50, {from: accounts[2]});

        // tangible funds should increase
        const fundsTangible = (await erc20Token.balanceOf.call(devestOne.address)).toNumber();
        assert.equal(fundsTangible, 4650000000, "Invalid funds after bid");

        const orders = await devestOne.getOrders.call();
        assert.equal(orders.length, 1, "Order not stored");
        assert.equal(orders[0].price, 30000000, "Order has invalid price");
    });

    it('Accept Buy Orders (A)', async () => {
        const erc20Token = await ERC20Token.deployed();
        const devestOne = await DevestOne.deployed();

        // fetch orders
        const orders = await devestOne.getOrders.call();
        await devestOne.accept(orders[0].from, 50, { from: accounts[0], value: 10000000 });

        // check if root got funds back
        const fundsPlayer = (await erc20Token.balanceOf(accounts[1])).toNumber();
        assert.equal(fundsPlayer, 75000000, "Invalid funds on player after buy order");

        const fundsTangible = (await erc20Token.balanceOf.call(devestOne.address)).toNumber();
        assert.equal(fundsTangible, 3075000000, "Invalid funds on tangible after accept");

        const balance = (await devestOne.getBalance.call()).toNumber();
        assert.equal(fundsTangible, balance, "Funds and balance should be same");

        const price = (await devestOne.getPrice.call()).toNumber();
        assert.equal(price, 30750000, "Invalid price, in PreSale phase");

        const share = (await devestOne.getShare.call(accounts[2])).toNumber();
        assert.equal(share, 50, "Invalid share of staker");
    })

    it('Check if orders been closed', async () => {
        const erc20Token = await ERC20Token.deployed();
        const devestOne = await DevestOne.deployed();

        const offers = await devestOne.getOrders.call();
        assert.equal(offers.length, 0, "Buy order not closed");

        const sharedholders = await devestOne.getShareholders.call();
        assert.equal(sharedholders.length, 2, "New shareholder not included in shareholders");
    });

    it('Add more buy orders', async () => {
        const erc20Token = await ERC20Token.deployed();
        const devestOne = await DevestOne.deployed();

        const price = (await devestOne.getPrice.call()).toNumber();

        // submit bid
        await createBid(20, price, accounts[3]);
        await createBid(10, price * 1.5, accounts[4]);
        await createBid(20, price * 2, accounts[5]);
        await createBid(20, price * 0.5, accounts[6]);

        // tangible funds should increase
        const fundsTangible = (await erc20Token.balanceOf.call(devestOne.address)).toNumber();
        assert.equal(fundsTangible, 5950125000, "Invalid funds submitting buy orders");

        const orders = await devestOne.getOrders.call();
        assert.equal(orders.length, 4, "Order not stored");
        assert.equal(orders[3].price, 15375000, "Order has invalid price");
    })

    it('Accept bids', async () => {
        const erc20Token = await ERC20Token.deployed();
        const devestOne = await DevestOne.deployed();

        let fundsTangible = (await erc20Token.balanceOf.call(devestOne.address)).toNumber();
        let fundsPlayer = (await erc20Token.balanceOf.call(accounts[1])).toNumber();
        let fundsOwner = (await erc20Token.balanceOf.call(accounts[0])).toNumber();
        let value = (await devestOne.getBalance.call()).toNumber();
        let earningOnwer = 0;

        // fetch offers
        const offers = await devestOne.getOrders.call();
        await devestOne.accept(offers[0].from, 20, { from: accounts[0] });

        fundsTangible = (await erc20Token.balanceOf.call(devestOne.address)).toNumber();
        value = (await devestOne.getBalance.call()).toNumber();
        fundsPlayer = (await erc20Token.balanceOf.call(accounts[1])).toNumber();
        earningOnwer += ((await erc20Token.balanceOf.call(accounts[0])).toNumber() - fundsOwner);
        fundsOwner = (await erc20Token.balanceOf.call(accounts[0])).toNumber();
        assert.equal(fundsPlayer, 105750000, "Invalid tax paid to player");

        await devestOne.accept(offers[1].from, 10, { from: accounts[0] });

        fundsTangible = (await erc20Token.balanceOf.call(devestOne.address)).toNumber();
        value = (await devestOne.getBalance.call()).toNumber();
        fundsPlayer = (await erc20Token.balanceOf.call(accounts[1])).toNumber();
        earningOnwer += ((await erc20Token.balanceOf.call(accounts[0])).toNumber() - fundsOwner);
        fundsOwner = (await erc20Token.balanceOf.call(accounts[0])).toNumber();
        assert.equal(fundsPlayer, 128812500, "Invalid tax paid to player");

        await devestOne.accept(offers[2].from, 10, { from: accounts[0] });

        fundsTangible = (await erc20Token.balanceOf.call(devestOne.address)).toNumber();
        value = (await devestOne.getBalance.call()).toNumber();
        fundsPlayer = (await erc20Token.balanceOf(accounts[1])).toNumber();
        earningOnwer += ((await erc20Token.balanceOf.call(accounts[0])).toNumber() - fundsOwner);
        fundsOwner = (await erc20Token.balanceOf.call(accounts[0])).toNumber();
        assert.equal(fundsPlayer, 159562500, "Invalid funds on player after bid");

        fundsTangible = (await erc20Token.balanceOf.call(accounts[0])).toNumber();
        const total = 43000000000 + 3159562500;
        //assert.equal(fundsTangible, total, "Invalid funds on tangible after accept");
    });

    it('Accept bid, which is lower then price', async () => {
        const erc20Token = await ERC20Token.deployed();
        const devestOne = await DevestOne.deployed();

        let fundsTangible = (await erc20Token.balanceOf.call(devestOne.address)).toNumber();
        let fundsPlayer = (await erc20Token.balanceOf.call(accounts[1])).toNumber();
        let fundsOwner = (await erc20Token.balanceOf.call(accounts[2])).toNumber();
        let value = (await devestOne.getBalance.call()).toNumber();

        // accept offer
        const offers = await devestOne.getOrders.call();
        await devestOne.accept(offers[0].from, 10, { from: accounts[2] });

        let fundsTangibleAfter = (await erc20Token.balanceOf.call(devestOne.address)).toNumber();
        assert.equal(fundsTangibleAfter, 4012875000, "Invalid funds on tangible");

        let fundsPlayerAfter = (await erc20Token.balanceOf.call(accounts[1])).toNumber();
        assert.equal(fundsPlayerAfter, 167250000, "Invalid funds on tangible");

        let fundsOwnerAfter = (await erc20Token.balanceOf.call(accounts[2])).toNumber();
        assert.equal(fundsOwnerAfter, 38503750000, "Invalid funds on tangible");

        let valueAfter = (await devestOne.getBalance.call()).toNumber();
        assert.equal(valueAfter, 3167250000, "Invalid funds on tangible");
    });

    it('Cancel offer, and get escrow back', async () => {
        const erc20Token = await ERC20Token.deployed();
        const devestOne = await DevestOne.deployed();

        let orders = await devestOne.getOrders.call();

        let fundsTangible = (await erc20Token.balanceOf.call(devestOne.address)).toNumber();
        let fundsOwner = (await erc20Token.balanceOf.call(accounts[6])).toNumber();

        // has 10 amount left in offer
        await devestOne.cancel({ from: accounts[5] });
        await devestOne.cancel({ from: accounts[6] });

        // check offers
        orders = await devestOne.getOrders.call();
        assert.equal(orders.length, 0, "Offers was not cancelled");

        let fundsTangibleAfter = (await erc20Token.balanceOf.call(devestOne.address)).toNumber();
        let fundsOwnerAfter = (await erc20Token.balanceOf.call(accounts[6])).toNumber();

        assert.equal(fundsTangibleAfter, 3167250000, "Escrow not returned");
    });

    it('Submit ask order', async () => {
        const erc20Token = await ERC20Token.deployed();
        const devestOne = await DevestOne.deployed();

        const price = (await devestOne.getPrice.call()).toNumber();

        // test to submit sell order without having shares
        try {
            await devestOne.offer(price * 0.5, 20, { from: accounts[7] });
        } catch (ex){
            assert.equal(ex.reason, "No shares available", "Should fail");
        }

        // check current amount of shares
        let currentShares = (await devestOne.getShare.call(accounts[2])).toNumber();
        assert.equal(currentShares, 40, "Escrow not returned");

        // offer shares
        await devestOne.offer(price * 0.5, 20, { from: accounts[2] });

        // get orders
        const orders = await devestOne.getOrders.call();
        assert.equal(orders[0].amount, 20, "Order not booked");
    });

    it('Accept sell order', async() => {
        const erc20Token = await ERC20Token.deployed();
        const devestOne = await DevestOne.deployed();

        const price = (await devestOne.getPrice.call()).toNumber();
        const cost = (price * 0.5) * 10;
        const taxAndContribution = cost * 0.10;

        const fundsTangibleBefore = (await erc20Token.balanceOf.call(devestOne.address)).toNumber();
        const fundsPlayerBefore = (await erc20Token.balanceOf.call(accounts[1])).toNumber();
        const fundsOwnerBefore = (await erc20Token.balanceOf.call(accounts[2])).toNumber();
        const shareOwnerBefore = (await devestOne.getShare.call(accounts[2])).toNumber();
        const fundsBuyerBefore = (await erc20Token.balanceOf.call(accounts[7])).toNumber();
        const balanceBefore = (await devestOne.getBalance.call()).toNumber();

        await erc20Token.approve(devestOne.address, cost + taxAndContribution , { from: accounts[7] });
        await devestOne.acceptOffer(accounts[2], 10, { from: accounts[7] });

        const fundsTangibleAfter = (await erc20Token.balanceOf.call(devestOne.address)).toNumber();
        assert.equal(fundsTangibleAfter, fundsTangibleBefore + (taxAndContribution / 2), "Invalid funds on TST");

        const fundsPlayerAfter = (await erc20Token.balanceOf.call(accounts[1])).toNumber();
        assert.equal(fundsPlayerAfter, fundsPlayerBefore + (taxAndContribution / 2), "Invalid funds on Player");

        const fundsOwnerAfter = (await erc20Token.balanceOf.call(accounts[2])).toNumber();
        assert.equal(fundsOwnerAfter, fundsOwnerBefore + cost, "Invalid funds on Seller");

        const shareOwnerAfter = (await devestOne.getShare.call(accounts[2])).toNumber();
        assert.equal(shareOwnerAfter, shareOwnerBefore-10, "Shares not taken of Seller");

        const fundsBuyerAfter = (await erc20Token.balanceOf.call(accounts[7])).toNumber();
        assert.equal(fundsBuyerAfter, fundsBuyerBefore - cost - taxAndContribution, "Invalid funds on Buyer (Paid to less?)");

        const balanceAfter = (await devestOne.getBalance.call()).toNumber();
        assert.equal(balanceAfter, fundsTangibleAfter, "TST Balance not equal actual Balance");

        // check shares
        const sellerShares = (await devestOne.getShare.call(accounts[2])).toNumber();
        const buyerShares = (await devestOne.getShare.call(accounts[7])).toNumber();
        assert.equal(sellerShares, 30, "Seller has not less shares after sale");
        assert.equal(buyerShares, 10, "Buyer didn't receiver shares");
    });

    it('Disburse funds', async() => {
        const erc20Token = await ERC20Token.deployed();
        const devestOne = await DevestOne.deployed();

        const fundsTangibleBefore = (await erc20Token.balanceOf.call(devestOne.address)).toNumber();

        await erc20Token.approve(devestOne.address, 100000000, { from: accounts[0] })
        await devestOne.disburse(100000000, { from: accounts[0] } );

        // WRONG => Now all owners should have higher balance but tangible should be empty.
        const fundsTangibleAfter = (await erc20Token.balanceOf.call(devestOne.address)).toNumber();
        const value = (await devestOne.getBalance.call()).toNumber();
        const price = (await devestOne.getPrice.call()).toNumber();

        assert.equal(fundsTangibleAfter, fundsTangibleBefore + 100000000, "Disburse failed TST Balance invalid");
        assert.equal(fundsTangibleAfter, value, "Disburse failed - Balance not match");
        assert.equal(price, Math.round(fundsTangibleAfter / 100), "Disburse failed");
    })

    it('Terminate Share', async () => {
        const erc20Token = await ERC20Token.deployed();
        const devestOne = await DevestOne.deployed();

        // check all holders
        const shares = [];
        const sharesP = [];
        const shareholders = await devestOne.getShareholders.call();
        let shareSummary = 0;
        let pSummary = 0;
        for(let share of shareholders) {
            const amount = (await erc20Token.balanceOf.call(share)).toNumber();
            shares.push(amount);
            shareSummary += amount;

            const p = (await devestOne.getShare.call(share)).toNumber();
            sharesP.push(p);
            pSummary += p;
        }

        const totalBalance = (await erc20Token.balanceOf.call(devestOne.address)).toNumber();
        //assert.equal(totalBalance, shareSummary, "Invalid Balance or Shares");

        // terminate
        await devestOne.terminate({ from: accounts[0] });

        // check balances in share
        const fundsTangibleAfter = (await erc20Token.balanceOf.call(devestOne.address)).toNumber();
        assert.ok(fundsTangibleAfter < 1000, "Tangible shouldn't have anymore funds");

        const offers = await devestOne.getOrders.call();

        let index = 0;
        for(let share of shareholders){
            const balance = (await erc20Token.balanceOf.call(share)).toNumber();
            const before = shares[index];
        }

    });

});

const createBid = async (percent, price, address) => {
    const erc20Token = await ERC20Token.deployed();
    const devestOne = await DevestOne.deployed();

    // submit bid
    let escrow = price * percent;
    escrow = escrow + (escrow * 0.1)
    await erc20Token.approve(devestOne.address, escrow, { from: address });
    await devestOne.bid(price, percent, {from: address});
}
