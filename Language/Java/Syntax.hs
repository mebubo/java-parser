{-# LANGUAGE DeriveDataTypeable    #-}
{-# LANGUAGE DeriveGeneric         #-}
{-# LANGUAGE FlexibleInstances     #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE ScopedTypeVariables   #-}
{-# LANGUAGE TypeSynonymInstances  #-}

module Language.Java.Syntax where

import           Data.Data
import           GHC.Generics               (Generic)

import           Data.Function              (on)
import           Language.Java.Syntax.Exp
import           Language.Java.Syntax.Types

-----------------------------------------------------------------------
-- Packages

-- | A compilation unit is the top level syntactic goal symbol of a Java program.
data CompilationUnit l
  = CompilationUnit
    { infoCompUnit    :: l
    , packageLocation :: Maybe (PackageDecl l)
    , imports         :: [ImportDecl l]
    , typeDecls       :: [TypeDecl l]
    }
  deriving (Eq,Show,Read,Typeable,Generic,Data)

data ModuleDeclaration l = ModuleDeclaration
    { infoModuleDecl :: l
    , modulePackage  :: Package
    , moduleSpecs    :: [ModuleSpec l]
    }
  deriving (Eq,Show,Read,Typeable,Generic,Data)

-- | A package declaration appears within a compilation unit to indicate the package to which the compilation unit belongs.
data PackageDecl l = PackageDecl { infoPackDec :: l, packageDecl :: Package}
  deriving (Eq,Show,Read,Typeable,Generic,Data)

-- | requires the module to work
data ModuleRequires l
  = ModuleRequires
  { infoModuleRequires :: l
  , requireModule      :: Package
  }
  deriving (Eq,Show,Read,Typeable,Generic,Data)

  -- | exports the package
data ModuleExports l = ModuleExports
  { infoModuleExports :: l
  , exportsPackage    :: Package
  }
  deriving (Eq,Show,Read,Typeable,Generic,Data)

-- | An import declaration allows a static member or a named type to be referred to by a single unqualified identifier.
--   The first argument signals whether the declaration only imports static members.
--   The last argument signals whether the declaration brings all names in the named type or package, or only brings
--   a single name into scope.
data ImportDecl l = ImportDecl
  { infoImportDecl :: l
  , staticImport   :: Bool
  , importPackage  :: Package
  }
  deriving (Eq,Show,Read,Typeable,Generic,Data)

instance HasType (ImportDecl l) where
  getType = getTypeFromPackage . importPackage

getTypeFromPackage :: Package -> Type
getTypeFromPackage pkg = RefType $ ClassRefType $ WithPackage pkg WildcardName

-----------------------------------------------------------------------
-- Declarations


-- | A type declaration declares a class type or an interface type.
data ClassTypeDecl l = ClassTypeDecl { infoClassTypeDecl :: l, classDecl :: ClassDecl l }
data InterfaceTypeDecl l = InterfaceTypeDecl { infoInterfaceTypeDecl :: l, interfaceDecl :: InterfaceDecl l}
  deriving (Eq,Show,Read,Typeable,Generic,Data)

-- | Get type of TypeDecl
instance HasType (TypeDecl l) where
  getType (ClassTypeDecl _ ctd) = getType ctd
  getType (InterfaceTypeDecl _ itd) = getType itd

instance CollectTypes (TypeDecl l) where
  collectTypes (ClassTypeDecl _ ctd) = collectTypes ctd
  collectTypes (InterfaceTypeDecl _ itd) = collectTypes itd

-- | Get the body of TypeDecl
instance HasBody (TypeDecl l) l where
  getBody (ClassTypeDecl _ classDeclB) = getBody classDeclB
  getBody (InterfaceTypeDecl _ iterDecl) = getBody iterDecl

-- | A class declaration specifies a new named reference type.
data ClassDecl l
    = ClassDecl
      { infoClassDecl      :: l
      , classDeclModifiers :: [Modifier l]
      , classDeclName      :: Ident
      , classTypeParams    :: [TypeParam]
      , extends            :: Maybe (Extends l)
      , implements         :: [Implements l]
      , classBody          :: ClassBody l
      }
data EnumDecl l = EnumDecl
      { infoEnumDecl      :: l
      , enumDeclModifiers :: [Modifier l]
      , enumeDeclName     :: Ident
      , implements        :: [Implements l]
      , enumBody          :: EnumBody l
      }
  deriving (Eq,Show,Read,Typeable,Generic,Data)

-- | Get type of ClassDecl
instance HasType (ClassDecl l) where
  getType (ClassDecl _ _ i _ _ _ _) = withoutPackageIdentToType i
  getType (EnumDecl _ _ i _ _) = withoutPackageIdentToType i

-- | Get the body of ClassDecl
instance HasBody (ClassDecl l) l where
  getBody (ClassDecl _ _ _ _ _ _ classBodyB) = getBody classBodyB
  getBody (EnumDecl _ _ _ _ enumBodyB) = getBody enumBodyB

instance CollectTypes (ClassDecl l) where
  collectTypes (ClassDecl _ _ i _ _ types _) = withoutPackageIdentToType i : collectTypes types
  collectTypes (EnumDecl _ _ i types _) = withoutPackageIdentToType i : collectTypes types

-- | An extends clause
data Extends l = Extends { infoExtends :: l, extendsClass :: RefType }
  deriving (Eq,Show,Read,Typeable,Generic,Data)

instance HasType (Extends l) where
  getType = getType . extendsClass

-- | An implements clause
data Implements l = Implements { infoImplements :: l, implementsInterface :: RefType }
  deriving (Eq,Show,Read,Typeable,Generic,Data)

instance HasType (Implements l) where
  getType = getType . implementsInterface

-- | A class body may contain declarations of members of the class, that is,
--   fields, classes, interfaces and methods.
--   A class body may also contain instance initializers, static
--   initializers, and declarations of constructors for the class.
data ClassBody l = ClassBody { infoClassBody :: l, classDecls :: [Decl l] }
  deriving (Eq,Show,Read,Typeable,Generic,Data)

-- | Get the body of ClassBody
instance HasBody (ClassBody l) l where
  getBody (ClassBody _ decls) = decls

-- | The body of an enum type may contain enum constants.
data EnumBody l = EnumBody { infoEnumBody :: l, enumConstans :: [EnumConstant l], enumDecls :: [Decl l] }
  deriving (Eq,Show,Read,Typeable,Generic,Data)

-- | Get the body of EnumBody
instance HasBody (EnumBody l) l where
  getBody (EnumBody _ _ decls) = decls

-- | An enum constant defines an instance of the enum type.
data EnumConstant l = EnumConstant
  { infoEnumConstant :: l
  , enumConstantName :: Ident
  , enumArguments    :: [Argument l]
  , enumConstantBody :: Maybe (ClassBody l)
  }
  deriving (Eq,Show,Read,Typeable,Generic,Data)

-- | Get type of EnumConstant
instance HasType (EnumConstant l) where
  getType (EnumConstant _ i _ _) =  withoutPackageIdentToType i

-- | An interface declaration introduces a new reference type whose members
--   are classes, interfaces, constants and abstract methods. This type has
--   no implementation, but otherwise unrelated classes can implement it by
--   providing implementations for its abstract methods.
data InterfaceDecl l = InterfaceDecl
  { infoInterfaceDecl      :: l
  , interfaceKind          :: InterfaceKind
  , interfaceDeclModifiers :: [Modifier l]
  , interfaceDeclName      :: Ident
  , interfaceTypeParams    :: [TypeParam]
  , interfaceExtends       :: [Extends l]
  , interfaceBody          :: InterfaceBody l
  }
  deriving (Eq,Show,Read,Typeable,Generic,Data)

-- | Get type of InterfaceDecl
instance HasType (InterfaceDecl l) where
  getType (InterfaceDecl _ _ _ i _ _ _) =  withoutPackageIdentToType i

instance CollectTypes (InterfaceDecl l) where
  collectTypes (InterfaceDecl _ _ _ i _ types _) = withoutPackageIdentToType i : collectTypes types

-- | Get the body of InterfaceDecl
instance HasBody (InterfaceDecl l) l where
  getBody (InterfaceDecl _ _ _ _ _ _ iterBody) = getBody iterBody

-- | Interface can declare either a normal interface or an annotation
data InterfaceKind = InterfaceNormal | InterfaceAnnotation
  deriving (Eq,Show,Read,Typeable,Generic,Data)

-- | The body of an interface may declare members of the interface.
data InterfaceBody l
    = InterfaceBody { infoInterfaceBody ::l, members :: [MemberDecl l]}
  deriving (Eq,Show,Read,Typeable,Generic,Data)

-- | Get the body of ClassDecl
instance HasBody (InterfaceBody l) l where
  getBody (InterfaceBody l memDecls) = map (MemberDecl l) memDecls

-- | A declaration is either a member declaration, or a declaration of an
--   initializer, which may be static.
data Decl l = MemberDecl { infoMemberDecl :: l, member :: MemberDecl l }
data InitDecl l = InitDecl { infoInitDecl :: l, staticDecl :: Bool, statements :: Block l }
  deriving (Eq,Show,Read,Typeable,Generic,Data)


-- | The variables of a class type are introduced by field declarations.
--
-- Example:
--
-- >>> parseCompilationUnit "public class MyClass {private String foo = \"Hello World\"; }"
-- ...
-- __FieldDecl__ {__infoFieldDecl__ = Segment (Position 1 31) (Position 1 31), __memberDeclModifiers__ = [private], __fieldType__ =
-- RefType (ClassRefType (WithoutPackage (ClassName [(Ident "String",[])]))), __fieldVarDecls__ = [VarDecl {infoVarDecl =
-- Segment (Position 1 38) (Position 1 38), varDeclName = VarId {infoVarId = Segment (Position 1 38) (Position 1 38),
-- varIdName = Ident "foo"}, varInit = Just (InitExp {infoInitExp= Segment (Position 1 44) (Position 1 44), init = Lit
-- {infoLit = Segment (Position 1 44) (Position 1 44), literal = String "Hello World"}})}]}}]}}}]})
data FieldDecl l = FieldDecl
      { infoFieldDecl       :: l
      , memberDeclModifiers :: [Modifier l]
      , fieldType           :: Type
      , fieldVarDecls       :: [VarDecl l]
      }
-- | A method declares executable code that can be invoked, passing a fixed number of values as arguments.
-- Example:
--
-- >>> parseCompilationUnit "public class MyClass {private String foo() {}}"
-- ...
-- [MemberDecl {infoMemberDecl = Segment (Position 1 23) (Position 1 23), member = MethodDecl {infoMethodDecl =
-- Segment (Position 1 31) (Position 1 31), methodDeclModifiers = [private], methodTypeParams = [], returnType =
-- Just (RefType (ClassRefType (WithoutPackage (ClassName [(Ident "String",[])])))), methodDeclName = Ident "foo", params = [],
-- exceptions = [], defaultInterfaceAnnotation = Nothing, methodBody = MethodBody {infoMethodBody = Segment (Position 1 44)
-- (Position 1 44), impl= Just (Block {infoBlock = Segment (Position 1 45) (Position 1 45), blockStatements = []})}}}]}}}]})
data MethodDecl l =  MethodDecl
      { infoMethodDecl             :: l
      , methodDeclModifiers        :: [Modifier l]
      , methodTypeParams           :: [TypeParam]
      , returnType                 :: Maybe Type
      , methodDeclName             :: Ident
      , params                     :: [FormalParam l]
      , exceptions                 :: [ExceptionType l]
      , defaultInterfaceAnnotation :: Maybe (Exp l)
      , methodBody                 :: MethodBody l
      }

-- | A constructor is used in the creation of an object that is an instance of a class.
data ConstructorDecl l = ConstructorDecl
      { infoConstructorDecl     :: l
      , constructorMod          :: [Modifier l]
      , constructorTypeParams   :: [TypeParam]
      , constructorClassName    :: Ident
      , constructorFormalParams :: [FormalParam l]
      , constructorExceptions   :: [ExceptionType l]
      , constructorBody         :: ConstructorBody l
      }
-- | A member class is a class whose declaration is directly enclosed in another class or interface declaration.
data MemberClassDecl l = MemberClassDecl
      { infoMemberClassDecl :: l
      , memberClassDecl     :: ClassDecl l
      }

-- | A member interface is an interface whose declaration is directly enclosed in another class or interface declaration.
data MemberInterfaceDecl l =  MemberInterfaceDecl
      { infoMemberInterfaceDecl :: l
      , memberInterfaceDecls    :: InterfaceDecl l
      }
  deriving (Eq,Show,Read,Typeable,Generic,Data)

-- | Get type of MemberDecl if it is a MethodDecl (our solution to handeling the Maybe)
instance CollectTypes (MemberDecl l) where
  collectTypes (FieldDecl _ _ t _) =  [t]
  collectTypes (MethodDecl _ _ _ _ name _ _ _ _) =  [withoutPackageIdentToType name]
  collectTypes ConstructorDecl{} = []
  collectTypes (MemberClassDecl _ cd) =  [getType cd]
  collectTypes (MemberInterfaceDecl _ idecl) =  [getType idecl]

instance Eq l => Ord (MemberDecl l) where
  compare = compare `on` memToInt
    where
      memToInt FieldDecl{} = 1
      memToInt MethodDecl{} = 2
      memToInt ConstructorDecl{} = 3
      memToInt MemberClassDecl{} = 4
      memToInt MemberInterfaceDecl{} = 5

-- | A declaration of a variable, which may be explicitly initialized.
data VarDecl l = VarDecl { infoVarDecl :: l, varDeclName :: VarDeclId l, varInit :: Maybe (VarInit l) }
  deriving (Eq,Show,Read,Typeable,Generic,Data)

-- | The name of a variable in a declaration, which may be an array.
data VarId l = VarId { infoVarId :: l, varIdName :: Ident }
data VarDeclArray l = VarDeclArray { infoVarDeclArray :: l, varIdDecl :: VarDeclId l }
    -- ^ Multi-dimensional arrays are represented by nested applications of 'VarDeclArray'.
  deriving (Eq,Show,Read,Typeable,Generic,Data)

-- | Explicit initializer for a variable declaration.
data InitExp l = InitExp { infoInitExp :: l, init :: Exp l }
data InitArray l =  InitArray { infoInitArray :: l, varArrayInit :: ArrayInit l }
  deriving (Eq,Show,Read,Typeable,Generic,Data)

-- | A formal parameter in method declaration. The last parameter
--   for a given declaration may be marked as variable arity,
--   indicated by the boolean argument.
data FormalParam l = FormalParam
  { infoFormalParam      :: l
  , formalParamModifiers :: [Modifier l]
  , paramType            :: Type
  , variableArity        :: Bool
  , paramName            :: VarDeclId l
  }
  deriving (Eq,Show,Read,Typeable,Generic,Data)

-- | Gets type of FormalParam
instance HasType (FormalParam l) where
  getType (FormalParam _ _ t _ _) =  t

-- | A method body is either a block of code that implements the method or simply a
--   semicolon, indicating the lack of an implementation (modelled by 'Nothing').
data MethodBody l = MethodBody { infoMethodBody :: l, impl :: Maybe (Block l) }
  deriving (Eq,Show,Read,Typeable,Generic,Data)

-- | The first statement of a constructor body may be an explicit invocation of
--   another constructor of the same class or of the direct superclass.
data ConstructorBody l = ConstructorBody
  { infoConstructorBody :: l
  , constructorInvoc    :: Maybe (ExplConstrInv l)
  , constrBody          :: [BlockStmt l]
  }
  deriving (Eq,Show,Read,Typeable,Generic,Data)

-- | An explicit constructor invocation invokes another constructor of the
--   same class, or a constructor of the direct superclass, which may
--   be qualified to explicitly specify the newly created object's immediately
--   enclosing instance.
data ThisInvoke l = ThisInvoke
      { infoThisInvoke  :: l
      , typeArguments   :: [RefType]
      , constrArguments :: [Argument l]
      }
data SuperInvoke l = SuperInvoke
      { infoSuperInvoke :: l
      , typeArguments   :: [RefType]
      , constrArguments :: [Argument l]
      }
data PrimarySuperInvoke l = PrimarySuperInvoke
      { infoPrimarySuperInvoke :: l
      , primary                :: Exp l
      , typeArguments          :: [RefType]
      , constrArguments        :: [Argument l]
      }
  deriving (Eq,Show,Read,Typeable,Generic,Data)


-- | A modifier specifying properties of a given declaration. In general only
--   a few of these modifiers are allowed for each declaration type, for instance
--   a member type declaration may only specify one of public, private or protected.
data Modifier l
    = Public l
    | Private l
    | Protected l
    | Abstract l
    | Final l
    | Static l
    | StrictFP l
    | Transient l
    | Volatile l
    | Native l
    | Annotation l (Annotation l)
    | Synchronized_ l
    | DefaultModifier l
  deriving (Eq,Read,Typeable,Generic,Data)

instance (Show l) => Show (Modifier l) where
   show (Public _) = "public"
   show (Private _) = "private"
   show (Protected _) = "protected"
   show (Abstract _) = "abstract"
   show (Final _) = "final"
   show (Static _) = "static"
   show (StrictFP _) = "strictfp"
   show (Transient _) = "transient"
   show (Volatile _) = "volatile"
   show (Native _) = "native"
   show (Annotation _ a) = show a
   show (Synchronized_ _) = "synchronized"
   show (DefaultModifier _) = "default"

-- | Annotations have three different forms: no-parameter, single-parameter or key-value pairs
data Annotation l = NormalAnnotation      { annName :: Name -- Not type because not type generics not allowed
                                          , annKV   :: [(Ident, ElementValue l)] }
                | SingleElementAnnotation { annName  :: Name
                                          , annValue:: ElementValue l }
                | MarkerAnnotation        { annName :: Name }
  deriving (Eq,Show,Read,Typeable,Generic,Data)

-- | Annotations may contain  annotations or (loosely) expressions
data ElementValue l = EVVal { infoEVVal :: l, elementVarInit :: VarInit l }
                  | EVAnn { infoEVAnn :: l, annotation :: Annotation l}
  deriving (Eq,Show,Read,Typeable,Generic,Data)

-----------------------------------------------------------------------
-- Statements

-- | A block is a sequence of statements, local class declarations
--   and local variable declaration statements within braces.
data Block l = Block { infoBlock :: l, blockStatements :: [BlockStmt l] }
  deriving (Eq,Show,Read,Typeable,Generic,Data)

-- | A block statement is either a normal statement, a local
--   class declaration or a local variable declaration.
data BlockStmt l
    = BlockStmt { infoBlockStmt :: l, statement :: Stmt l }
data LocalClass l =  LocalClass { infoLocalClass :: l, blockLocalClassDecl :: ClassDecl l }
data LocalVars l = LocalVars
      { infoLocalVars    :: l
      , locaVarModifiers :: [Modifier l]
      , blockVarType     :: Type
      , localVarDecls    :: [VarDecl l]
      }
  deriving (Eq,Show,Read,Typeable,Generic,Data)


-- | A statement can be a nested block.
data StmtBlock l = StmtBlock { infoStmtBlock :: l, block :: Block l }
    -- | The @if-then@ statement allows conditional execution of a statement.
data IfThenElse l =  IfThenElse { infoIfThenElse :: l, ifExp :: Exp l, thenExp :: Stmt l, elseExp :: Maybe (Stmt l) }
    -- | The @while@ statement executes an expression and a statement repeatedly until the value of the expression is false.
data While l = While { infoWhile :: l, whileVondition :: Exp l, whileBody :: Stmt l }
    -- | The basic @for@ statement executes some initialization code, then executes an expression, a statement, and some
    --   update code repeatedly until the value of the expression is false.
data BasicFor l = BasicFor
      { infoBasicFor :: l
      , forInit      :: Maybe (ForInit l)
      , forCond      :: Maybe (Exp l)
      , forUpdate    :: Maybe [Exp l]
      , forBody      :: Stmt l
      }
    -- | The enhanced @for@ statement iterates over an array or a value of a class that implements the @iterator@ interface.
data EnhancedFor l = EnhancedFor
      { infoEnhancedFor  :: l
      , loopVarModifiers :: [Modifier l] -- ^ example: for (final Int x : set) {..}
      , loopVarType      :: Type
      , loopVarName      :: Ident
      , iterable         :: Exp l
      , forBody          :: Stmt l
      }
    -- | An empty statement does nothing.
newtype Empty l = Empty { infoEmpty :: l }
    -- | Certain kinds of expressions may be used as statements by following them with semicolons:
    --   assignments, pre- or post-inc- or decrementation, method invocation or class instance
    --   creation expressions.
data ExpStmt l = ExpStmt { infoExpStmt :: l, exp :: Exp l }
    -- | An assertion is a statement containing a boolean expression, where an error is reported if the expression
    --   evaluates to false.
data Assert l = Assert { infoAssert :: l, booleanExp :: Exp l, valueExp :: Maybe (Exp l) }
    -- | The switch statement transfers control to one of several statements depending on the value of an expression.
data Switch l = Switch { infoSwitch :: l, switchValue :: Exp l, switchBlocks :: [SwitchBlock l] }
    -- | The @do@ statement executes a statement and an expression repeatedly until the value of the expression is false.
data Do l = Do { infoDo :: l, doBody :: Stmt l, doCondition :: Exp l }
    -- | A @break@ statement transfers control out of an enclosing statement.
data Break l = Break { infoBreak :: l, breakLabel :: Maybe Ident }
    -- | A @continue@ statement may occur only in a while, do, or for statement. Control passes to the loop-continuation
    --   point of that statement.
data Continue l = Continue { infoContinue :: l, continueLabel :: Maybe Ident }
    -- A @return@ statement returns control to the invoker of a method or constructor.
data Return l = Return { infoReturn :: l, returnExp :: Maybe (Exp l) }
    -- | A @synchronized@ statement acquires a mutual-exclusion lock on behalf of the executing thread, executes a block,
    --   then releases the lock. While the executing thread owns the lock, no other thread may acquire the lock.
data Synchronized l = Synchronized { infoSynchronized :: l, synchronizeOn :: Exp l, synchronizeBloc :: Block l }
    -- | A @throw@ statement causes an exception to be thrown.
data Throw l = Throw { infoThrow :: l, throwExp :: Exp l }
    -- | A try statement executes a block. If a value is thrown and the try statement has one or more catch clauses that
    --   can catch it, then control will be transferred to the first such catch clause. If the try statement has a finally
    --   clause, then another block of code is executed, no matter whether the try block completes normally or abruptly,
    --   and no matter whether a catch clause is first given control.
data Try l = Try
      { infoTry     :: l
      , tryResource :: [TryResource l]
      , tryBlock    :: Block l
      , catches     :: [Catch l]
      , finally     ::  Maybe (Block l)
      }
    -- | Statements may have label prefixes.
    | Labeled { infoLabeled :: l, label :: Ident, labeledStmt :: Stmt l }
  deriving (Eq,Show,Read,Typeable,Generic,Data)

-- | If a value is thrown and the try statement has one or more catch clauses that can catch it, then control will be
--   transferred to the first such catch clause.
data Catch l = Catch { infoCatch :: l, catchParam :: FormalParam l, catchBlock :: Block l }
  deriving (Eq,Show,Read,Typeable,Generic,Data)

    -- | Newly declared variables
data TryResourceVar l = TryResourceVar
    { infoTryResourceVar :: l
    , resourceModifiers  :: [Modifier l]
    , resourceVarType    :: RefType -- restricted to ClassType or TypeVariable
    , resourceVarDecl    :: [VarDecl l]
    }
    -- | Effectively final variable
data TryResourceFinalVar l = TryResourceFinalVar
    { infoTryResourceFinalVar :: l
    , resourceFinalVarName    :: Ident
    }
    deriving (Eq,Show,Read,Typeable,Generic,Data)

-- | A block of code labelled with a @case@ or @default@ within a @switch@ statement.
data SwitchBlock l = SwitchBlock { infoSwitchBlock :: l, switchLabel :: SwitchLabel l, switchStmts :: [BlockStmt l] }
  deriving (Eq,Show,Read,Typeable,Generic,Data)

    -- | The expression contained in the @case@ must be a 'Lit' or an @enum@ constant.
data SwitchCase l = SwitchCase { infoSwitchCase :: l, switchExp :: Exp l}
newtype SwitchDefault l = SwitchDefault { infoDefault :: l }
  deriving (Eq,Show,Read,Typeable,Generic,Data)

-- | Initialization code for a basic @for@ statement.
data ForLocalVars l = ForLocalVars
      { infoForLocalVars :: l
      , forVarModifiers  :: [Modifier l]
      , forVarType       :: Type
      , forVarDecls      :: [VarDecl l]
      }
data ForInitExps l = ForInitExps { infoForInitExps :: l, initExpr :: [Exp l] }
  deriving (Eq,Show,Read,Typeable,Generic,Data)

-- | An exception type has to be a class type or a type variable.
data ExceptionType l = ExceptionType { infoExceptionType :: l, expectionType :: RefType } -- restricted to ClassType or TypeVariable
  deriving (Eq,Show,Read,Typeable,Generic,Data)

-- | Gets type of ExceptionType
instance HasType (ExceptionType l) where
  getType (ExceptionType _ x) = RefType x

-- | Arguments to methods and constructors are expressions.
type Argument = Exp


    -- | A literal denotes a fixed, unchanging value.
data ExpLit l = Lit { infoLit :: l, literal :: Literal }
    -- | A class literal, which is an expression consisting of the name of a class, interface, array,
    --   or primitive type, or the pseudo-type void (modelled by 'Nothing'), followed by a `.' and the token class.
data ClassLit l = ClassLit { infoClassLit :: l, classLit :: Maybe Type }
    -- | The keyword @this@ denotes a value that is a reference to the object for which the instance method
    --   was invoked, or to the object being constructed.
newtype This l = This { infoThis :: l }
    -- | Any lexically enclosing instance can be referred to by explicitly qualifying the keyword this.
    -- TODO: Fix Parser here
data QualifiedThis = QualifiedThis { infoQualifiedThis :: l, qualiType :: Type }
    -- | A class instance creation expression is used to create new objects that are instances of classes.
    -- | The first argument is a list of non-wildcard type arguments to a generic constructor.
    --   What follows is the type to be instantiated, the list of arguments passed to the constructor, and
    --   optionally a class body that makes the constructor result in an object of an /anonymous/ class.
data InstanceCreation = InstanceCreation
      { infoInstanceCreation :: l
      , typeArgs             :: [TypeArgument]
      , typeDecl             :: TypeDeclSpecifier
      , instanceArguments    :: [Argument l]
      , anonymousClass       :: Maybe (ClassBody l)
      }
    -- | A qualified class instance creation expression enables the creation of instances of inner member classes
    --   and their anonymous subclasses.
    {- TODO what is is the mysteryExp used for?-}
data QualInstanceCreation l = QualInstanceCreation
      { infoQualInstanceCreation :: l
      , mysteryExp               :: Exp l
      , typeArgs                 :: [TypeArgument]
      , className                :: Ident
      , qualiInstanceArguments   :: [Argument l]
      , anonymousClass           :: Maybe (ClassBody l)
      }
    -- | An array instance creation expression is used to create new arrays. The last argument denotes the number
    --   of dimensions that have no explicit length given. These dimensions must be given last.
data ArrayCreate l = ArrayCreate { infoArrayCreate :: l, arrayType :: Type, arrayDimExprs :: [Exp l], dimensions :: Int }
    -- | An array instance creation expression may come with an explicit initializer. Such expressions may not
    --   be given explicit lengths for any of its dimensions.
data ArrayCreateInit l = ArrayCreateInit { infoArrayCreateInit :: l, arrayType :: Type, dimensions :: Int, arrayCreatInit :: ArrayInit l }
    -- | A field access expression.
data FieldAccess l = FieldAccess { infoFieldAccess :: l, fieldAccess :: FieldAccess l }
    -- | A method invocation expression.
data MethodInv l = MethodInv { infoMethodInv :: l, methodInvoc :: MethodInvocation l }
    -- | An array access expression refers to a variable that is a component of an array.
data ArrayAccess l = ArrayAccess { infoArrayAccess :: l, arrayAccessIndex :: ArrayIndex l }
{-    | ArrayAccess Exp Exp -- Should this be made into a datatype, for consistency and use with Lhs? -}
    -- | An expression name, e.g. a variable.
data ExpName l = ExpName { infoExpName :: l, expName :: Name }
    -- | Post-incrementation expression, i.e. an expression followed by @++@.
data PostIncrement l = PostIncrement { infoPostIncrement :: l, postIncExp :: Exp l }
    -- | Post-decrementation expression, i.e. an expression followed by @--@.
data PostDecrement l = PostDecrement { infoPostDecrement :: l, postDecExp :: Exp l }
    -- | Pre-incrementation expression, i.e. an expression preceded by @++@.
data PreIncrement l = PreIncrement { infoPreIncrement :: l, preIncExp :: Exp l }
    -- | Pre-decrementation expression, i.e. an expression preceded by @--@.
data PreDecrement l = PreDecrement { infoPreDecrement :: l, preDecExp :: Exp l }
    -- | Unary plus, the promotion of the value of the expression to a primitive numeric type.
data PrePlus l = PrePlus  { infoPrePlus :: l, plusArg :: Exp l }
    -- | Unary minus, the promotion of the negation of the value of the expression to a primitive numeric type.
data PreMinus l = PreMinus { infoPreMinus :: l, minusArg :: Exp l }
    -- | Unary bitwise complementation: note that, in all cases, @~x@ equals @(-x)-1@.
data PreBitCompl l = PreBitCompl { infoPreBitCompl :: l, bitComplArg :: Exp l }
    -- | Logical complementation of boolean values.
data PreNot l = PreNot { infoPreNot :: l, notArg :: Exp l }
    -- | A cast expression converts, at run time, a value of one numeric type to a similar value of another
    --   numeric type; or confirms, at compile time, that the type of an expression is boolean; or checks,
    --   at run time, that a reference value refers to an object whose class is compatible with a specified
    --   reference type.
data Cast l = Cast { infoCast :: l, castTarget :: Type, castArg :: Exp l }
    -- | The application of a binary operator to two operand expressions.
data BinOp l = BinOp { infoBinOp :: l, binArgLeft :: Exp l, binOp :: Op, binOpRight :: Exp l }
    -- | Testing whether the result of an expression is an instance of some reference type.
data InstanceOf l = InstanceOf { infoInstanceOf :: l, instanceOfArg :: Exp l, instanceOfTarget :: RefType }
    -- | The conditional operator @? :@ uses the boolean value of one expression to decide which of two other
    --   expressions should be evaluated.
data Cond l = Cond { infoCond :: l, condition :: Exp l, conditionTrueExp :: Exp l, conditionFalseExp :: Exp l }
    -- | Assignment of the result of an expression to a variable.
data Assign l = Assign { infoAssign :: l, assignTarget :: Lhs l, assignOp :: AssignOp, assignSource :: Exp l }
    -- | Lambda expression
data Lambda l = Lambda { infoLambda :: l, lambdaParams :: LambdaParams l, lambdaExpression :: LambdaExpression l }
    -- | Method reference
data MethodRef l = MethodRef { infoMethodRef :: l, methodClass :: Name, methodName :: Ident }
  deriving (Eq,Show,Read,Typeable,Generic,Data)

-- | The left-hand side of an assignment expression. This operand may be a named variable, such as a local
--   variable or a field of the current object or class, or it may be a computed variable, as can result from
--   a field access or an array access.
data NameLhs l = NameLhs { infoNameLhs :: l, varLhsName :: Name }          -- ^ Assign to a variable
data FieldLhs l = FieldLhs { infoFieldLhs :: l, fieldLhsName :: FieldAccess l }  -- ^ Assign through a field access
data ArrayLhs l = ArrayLhs { infoArrayLhs :: l, arrayLhsIndex :: ArrayIndex l }   -- ^ Assign to an array
  deriving (Eq,Show,Read,Typeable,Generic,Data)

-- | Array access
data ArrayIndex l = ArrayIndex
  { infoArrayIndex :: l
  , arrayName      :: Exp l
  , arrayIndices   :: [Exp l]
  }
  deriving (Eq,Show,Read,Typeable,Generic,Data)

-- | A field access expression may access a field of an object or array, a reference to which is the value
--   of either an expression or the special keyword super.
data PrimaryFieldAccess l = PrimaryFieldAccess { infoPrimaryFieldAccess :: l, targetObject :: Exp l, targetField :: Ident } -- ^ Accessing a field of an object or array computed from an expression.
data SuperFieldAccess l = SuperFieldAccess { infoSuperFieldAccess :: l, superField :: Ident } -- ^ Accessing a field of the superclass.
data ClassFieldAccess l = ClassFieldAccess { infoClassFieldAccess :: l, targetClass :: Name, staticField :: Ident } -- ^ Accessing a (static) field of a named class.
  deriving (Eq,Show,Read,Typeable,Generic,Data)

-- ¦ A lambda parameter can be a single parameter, or mulitple formal or mulitple inferred parameters
data LambdaSingleParam l = LambdaSingleParam { infoLambdaSingleParam :: l, lambdaParamName :: Ident }
data LambdaFormalParams l = LambdaFormalParams { infoLambdaFormalParams :: l, lambdaFormalParams :: [FormalParam l] }
data LambdaInferredParams l = LambdaInferredParams { infoLambdaInferredParams :: l, lambdaParamNames :: [Ident] }
    deriving (Eq,Show,Read,Typeable,Generic,Data)

-- | Lambda expression, starting from java 8
data LambdaExpression l
    = LambdaExpression { infoLambdaExpression ::l, singleLambdaExp :: Exp l }
    | LambdaBlock { infoLambdaBlock :: l, lambdaBlock :: Block l }
  deriving (Eq,Show,Read,Typeable,Generic,Data)


    -- | Invoking a specific named method.
data MethodCall l = MethodCall { infoMethodCall :: l, methodCallName :: Name, methodCallArgs :: [Argument l] }
    -- | Invoking a method of a class computed from a primary expression, giving arguments for any generic type parameters.
data PrimaryMethodCall l = PrimaryMethodCall
      { infoPrimaryMethodCall :: l
      , methodCallTargetObj   :: Exp l
      , mysteryRefTypes       :: [RefType] {- TODO: mysteryRefTypes, prob. type args. not set in Parser -}
      , primaryMethodName     :: Ident
      , primaryMethodCallArgs :: [Argument l]
      }
    -- | Invoking a method of the super class, giving arguments for any generic type parameters.
data SuperMethodCall l = SuperMethodCall
      { infoSuperMethodCall :: l
      , superMethodTypeArgs :: [RefType]
      , superMethodName     :: Ident
      , superMethodArgs     :: [Argument l]
      }
    -- | Invoking a method of the superclass of a named class, giving arguments for any generic type parameters.
data ClassMethodCall l = ClassMethodCall
      { infoClassMethodCall :: l
      , methodClassTarget   :: Name
      , classMethodTypeArgs :: [RefType]
      , classMethodName     :: Ident
      , classMethodArgs     :: [Argument l]
      }
    -- | Invoking a method of a named type, giving arguments for any generic type parameters.
data TypeMethodCall l = TypeMethodCall
      { infoTypeMethodCall    :: l
      , typeMethodClassTarget :: Name
      , typeMethodTypeArgs    :: [RefType]
      , typeMethodName        :: Ident
      , typeMethodArgs        :: [Argument l]
      }
  deriving (Eq,Show,Read,Typeable,Generic,Data)

-- | An array initializer may be specified in a declaration, or as part of an array creation expression, creating an
--   array and providing some initial values
data ArrayInit l = ArrayInit { infoArrayInit :: l, arrayInits :: [VarInit l] }
  deriving (Eq,Show,Read,Typeable,Generic,Data)
