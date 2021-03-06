/**
 * The grammar file is used to generate a transformer for query rewriting in static/dynamic 
 * objectification.
 **/

tree grammar QueryRewriter;

options 
{
    output = AST;
	ASTLabelType = CommonTree;
	tokenVocab = PSOAPS;
	rewrite = false;
	k = 1;
}

@header
{
	package org.ruleml.psoa.transformer;
	
	import java.util.Set;
    import java.util.HashSet;
    import java.util.SortedSet;
    import java.util.Map;
    import java.util.LinkedHashMap;
	import org.ruleml.psoa.analyzer.*;
	
	import static org.ruleml.psoa.FreshNameGenerator.*;
}

@members
{
    // New / old variables in the current KB clause or query formula
    private Map<String, CommonTree> m_newVarNodes = new LinkedHashMap<String, CommonTree>();
    private Set<String> m_queryVars = null;
    private boolean m_isQuery = false;
    
    private KBInfoCollector m_KBInfo;
    private static String s_oidFuncName = "oidcons";
    
    public QueryRewriter(TreeNodeStream input, KBInfoCollector info)
    {
        this(input);
        m_KBInfo = info;
    }
    
    private CommonTree membershipRewriteTree(CommonTree oid, CommonTree type, PredicateInfo pi)
    {
        ArrayList<CommonTree> disjuncts = new ArrayList<CommonTree>();

        if (pi == null)
            return (CommonTree)adaptor.create(FALSITY, "FALSITY");
        
        SortedSet<Integer> arities = pi.getPositionalArities();
        
        for (int i = arities.last(); i > 0; i--)
        {
            String var = freshVarName(m_queryVars);
            CommonTree varNode = (CommonTree)adaptor.create(VAR_ID, var);
            m_newVarNodes.put(var, varNode);
        }
        
        for (Integer i : arities)
        {
            CommonTree disjunct, predApp, predAppType, predAppTuple, equality,
                       oidFuncApp, oidFuncType, oidFuncConst, oidFuncTuple;
            
            predApp = (CommonTree)adaptor.create(PSOA, "PSOA");
            predAppType = (CommonTree) adaptor.create(INSTANCE, "#");
            predAppType.addChild((CommonTree)adaptor.dupTree(type));
            predApp.addChild(predAppType);
            
            predAppTuple = (CommonTree)adaptor.create(TUPLE, "TUPLE");
            predAppTuple.addChild((CommonTree) adaptor.create(DEPSIGN, "+"));
            if (i > 0)
            {
                predApp.addChild(predAppTuple);
            }
            
            equality = (CommonTree) adaptor.create(EQUAL, "EQUAL");
            
            oidFuncApp = (CommonTree) adaptor.create(PSOA, "PSOA");
            oidFuncType = (CommonTree) adaptor.create(INSTANCE, "#");
            oidFuncConst = (CommonTree) adaptor.create(SHORTCONST, "SHORTCONST");
            
            oidFuncType.addChild(oidFuncConst);
            oidFuncConst.addChild((CommonTree)adaptor.create(LOCAL, s_oidFuncName));
            oidFuncApp.addChild(oidFuncType);
            
            oidFuncTuple = (CommonTree)adaptor.create(TUPLE, "TUPLE");
            oidFuncTuple.addChild((CommonTree) adaptor.create(DEPSIGN, "+"));
            oidFuncTuple.addChild((CommonTree)adaptor.dupTree(type));
            oidFuncApp.addChild(oidFuncTuple);

            equality.addChild((CommonTree)adaptor.dupTree(oid));
            equality.addChild(oidFuncApp);
            
            int j = i;
            for (CommonTree varNode : m_newVarNodes.values())
            {
                if (--j < 0)
                  break;
                predAppTuple.addChild((CommonTree)adaptor.dupTree(varNode));
                oidFuncTuple.addChild((CommonTree)adaptor.dupTree(varNode));
            }
            
            disjunct = (CommonTree)adaptor.create(AND, "AND");
            disjunct.addChild(predApp);
            disjunct.addChild(equality);
            disjuncts.add(disjunct);
        }
        
        // The predicate is only used as a nullary predicate
        if (m_newVarNodes.isEmpty())
            return disjuncts.get(0);
        
        if (disjuncts.size() == 1)
        {
            return disjuncts.get(0);
        }
        else
        {
            CommonTree disjunction = (CommonTree)adaptor.create(OR, "OR");
            
            for (CommonTree disjunct : disjuncts)
            {
                disjunction.addChild(disjunct);
            }
            
            return disjunction;
        }
    }
    
    private CommonTree oidFuncArgTree(CommonTree type, CommonTree tuple)
    {
        CommonTree tree = (CommonTree) adaptor.dupTree(tuple);
        
        tree.insertChild(1, (CommonTree)adaptor.dupTree(type));
        return tree;
    }
	
  	private CommonTree newVarsTree()
  	{
        CommonTree root = (CommonTree)adaptor.nil();
  	    
  	    for (Map.Entry<String, CommonTree> entry : m_newVarNodes.entrySet())
        {
           String var = entry.getKey();
           CommonTree node = entry.getValue();
           
           // Rename the variable name if it has been used in the clause
           if (m_queryVars.contains(var))
           {
              node.getToken().setText(freshVarName(m_queryVars));  
           }
           adaptor.addChild(root, node);
        }
        
        m_newVarNodes.clear();
        return root;
  	}
}

document
    :   ^(DOCUMENT base? prefix* importDecl* group?)
    ;

base
    :   ^(BASE IRI_REF)
    ;

prefix
    :   ^(PREFIX NAMESPACE IRI_REF)
    ;

importDecl
    :   ^(IMPORT IRI_REF IRI_REF?)
    ;

group
    :   ^(GROUP group_element*)
    ;

group_element
    :   rule
    |   group
    ;

query
@init
{
   m_queryVars = new HashSet<String>();
}
@after
{
   m_queryVars.clear();
   m_queryVars = null;
}
    :   formula
    ->  { m_newVarNodes.isEmpty() }? formula
    ->  ^(EXISTS { newVarsTree() } formula)
    ;
    
rule
    :  ^(FORALL VAR_ID+ clause)
    |   clause -> clause
    ;

clause
    :   ^(IMPLICATION head formula)
    |   head
    ;
    
head
    :   atomic
    |   ^(AND head+)
    |   ^(EXISTS VAR_ID+ head)
    ;
    
formula
    :   ^(AND formula+)
    |   ^(OR formula+)
    |   ^(EXISTS VAR_ID+ formula)
    |   FALSITY
    |   atomic
    |   external
    ;

atomic
    :   atom
    |   equal
    |   subclass
    ;

atom
    :   psoa[true]
    ;

equal
    :   ^(EQUAL term term)
    ;

subclass
    :   ^(SUBCLASS term term)
    
    ;
    
term returns [boolean isVariable]
@init
{
    $isVariable = false;
}
    :   constant
    |   VAR_ID
    { 
        $isVariable = true;
        if (m_queryVars != null)
            m_queryVars.add($VAR_ID.text);
    }
    |   psoa[false]
    |   external
    ;

external
    :   ^(EXTERNAL psoa[false])
    ;
    
psoa[boolean isAtomicFormula]
@init
{
    int i = 0;
    PredicateInfo pi = null;
}
    :   ^(PSOA oid=term?
            ^(INSTANCE type=term { pi = m_KBInfo.getPredInfo($type.tree.toStringTree()); } ) tuples+=tuple* slots+=slot*)
    -> // Function applications
       { !$isAtomicFormula }? ^(PSOA $oid? ^(INSTANCE $type) tuple* slot*)
    -> {
            m_KBInfo.hasHeadOnlyVariables()  // KB has head-only variables
         || !(pi == null || pi.isRelational())  // Atoms with non-relational predicates
         || (oid == null && $slots == null)  // Relational atom
         || $type.tree.getType() == TOP      // Top-typed queries
         || $type.tree.getType() == VAR_ID   // Predicate variable
       }? ^(PSOA $oid? ^(INSTANCE $type) tuple* slot*) 
    -> {   pi == null ||         // Predicate does not exist in KB
          !$oid.isVariable ||    // Psoa term with OID constants
          $slots != null         // Psoa term with slots
       }? FALSITY
    -> // Rewrite a pure membership query atom
       { $tuples == null }?
       { membershipRewriteTree($oid.tree, $type.tree, pi) }
    -> // Rewrite query atoms with tuples and OID variable
        ^(AND (^(PSOA ^(INSTANCE $type) tuple)
               ^(EQUAL $oid ^(PSOA ^(INSTANCE ^(SHORTCONST LOCAL[s_oidFuncName])) { oidFuncArgTree($type.tree, (CommonTree)$tuples.get(i++)) })))*)
    ;

tuple
    :   ^(TUPLE DEPSIGN term+)
    ;
    
slot
    :   ^(SLOT DEPSIGN term term)
    ;

constant
    :   ^(LITERAL IRI)
    |   ^(SHORTCONST constshort)
    |   TOP
    ;

constshort
    :   IRI
    |   LITERAL
    |   NUMBER
    |   LOCAL
    ;