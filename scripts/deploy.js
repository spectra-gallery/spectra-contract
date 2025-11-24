async function main() {
    const Spectra = await ethers.getContractFactory("Spectra");
 
    // Start deployment, returning a promise that resolves to a contract object
    const _spectra = await Spectra.deploy("0xE3e2537C654Af7c7a98989D11b4B669d7EDF6779", "0xdD87C2275A37f08F6207561CBca39aE9f4E8DfD3");   
    console.log("Contract deployed to address:", _spectra.address);
 }
 
 main()
   .then(() => process.exit(0))
   .catch(error => {
     console.error(error);
     process.exit(1);
   });