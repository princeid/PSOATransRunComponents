package org.ruleml.psoa.psoa2x.common;

import gnu.getopt.Getopt;
import gnu.getopt.LongOpt;

import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.IOException;

import org.ruleml.psoa.psoa2x.psoa2prolog.PrologTranslator;
import org.ruleml.psoa.psoa2x.psoa2tptp.*;

/** Command line utility to translate PSOA RuleML files into TPTP. */
public class RunTranslator {

	public static void main(String[] args) throws FileNotFoundException, IOException {
		args = new String[] { "D:\\Programs\\PSOATools\\PSOATransRun\\src\\test\\testKB.ruleml" };
		boolean importClosure = false;
		boolean hasQueryDoc = false;
		String queryDoc = "";
		String[] ruleBaseFileNames = null;
		LongOpt[] longOpts = new LongOpt[256];

		// Reserved short option names: i ?
		longOpts[0] = new LongOpt("help", LongOpt.NO_ARGUMENT, null, '?');
		longOpts[1] = new LongOpt("import_closure", LongOpt.NO_ARGUMENT, null,'i');
		longOpts[2] = new LongOpt("query", LongOpt.REQUIRED_ARGUMENT, null, 'q');

		Getopt optionsParse = new Getopt("", args, "?iq:", longOpts);
		for (int opt = optionsParse.getopt(); opt != -1; opt = optionsParse.getopt()) {
			
			switch (opt) {
				case '?':
					printUsage();
					System.exit(1);
	
				case 'i':
					importClosure = true;
					break;
					
				case 'q':
					hasQueryDoc = true;
					queryDoc = optionsParse.getOptarg();
					break;
					
				default:
					assert false;
			}
		}

		int optInd = optionsParse.getOptind();

		if (args.length > optInd) {
			ruleBaseFileNames = new String[args.length - optInd];
			for (int i = optInd; i < args.length; ++i)
				ruleBaseFileNames[i - optInd] = args[i];
		} else {
			System.out.println("% No rule base file specified.");
			printUsage();
			System.exit(1);
		}

		try {
//			ANTLRBasedTranslator translator = new TPTPASOTranslator();
//			ANTLRBasedTranslator translator = new DirectTranslator();
			ANTLRBasedTranslator translator = new PrologTranslator();
			for (int i = 0; i < ruleBaseFileNames.length; ++i) {
				translator.translateKB(new FileInputStream(ruleBaseFileNames[i]), System.out);
//				createBasicTreeParser(ruleBaseFileNames[i], false).document();
			}
			System.out.println();
			if (hasQueryDoc) {
				translator.translateQuery(new FileInputStream(queryDoc), System.out);
//				createBasicTreeParser(queryDoc, hasQueryDoc).query();
			}
		} catch (TranslatorException ex) {
			System.err.println("Error: " + ex);
			ex.printStackTrace();
			System.exit(1);
		}
	}

	private static void printUsage() {

		System.out.println("Usage: org.ruleml.RunTranslator [OPTIONS] <rule base file>+");
		System.out.println("Options:");
		System.out.println("\t--help -? \n\t\t Print this message.");
//		System.out.println("\t--import_closure -i \n\t\tProcess the whole import closures of the rule bases.");
		System.out.println("\t--query -q <query document file>\n\t\tQuery document for rulebases.");
	} // printUsage()

} // class Validator