\name{glmer2stan}
\alias{glmer2stan}
%- Also NEED an '\alias' for EACH other topic documented here.
\title{Define Stan model using glmer notation}
\description{
  Using standard formula notation from \code{glmer} (\code{lme4}), defines a Stan model (\code{rstan}) and optionally samples from the posterior. Can optionally compute DIC. Supports model families: "gaussian", "binomial", "poisson", "ordered", "gamma", and two zero-inflated families, "zigamma" and "zipoisson". A number of custom mixture and multiple-outcome models can be specified by using lists of formulas and family names.
}
\usage{
glmer2stan( formula , data , family="gaussian" , varpriors="flat" , 
    sample=TRUE , warmup=5000 , iter=10000 , chains=1 , initmethod="zero" , 
    extract=FALSE , calcDIC=FALSE , verbose=TRUE , 
    fixed_prefix="beta_" , vary_prefix="vary_" , ... )
}
%- maybe also 'usage' for other objects documented here.
\arguments{
  \item{formula}{Model formula or list of formulas, using \code{\link{glmer}} notation for varying effects.}
  \item{data}{Data frame or list}
  \item{family}{Model family name or list of names for outcome(s). Valid choices are: "gaussian", "binomial" (logit link), "poisson" (log link), "ordered" (cumulative logit), "gamma" (log link), "zigamma" (zero-inflated gamma, logit and log links), or "zipoisson" (zero-inflated poisson, logit and log links).}
  \item{varpriors}{Variance prior presets. Valid choices are \code{'weak'} and \code{'flat'}. See details below.}
  \item{sample}{Whether or not to sample from the posterior (\code{TRUE}) or just return model code (\code{FALSE})}
  \item{warmup}{rstan parameter: number of adaptation samples}
  \item{iter}{rstan parameter: total number of samples, including warmup}
  \item{chains}{rstan parameter: number of chains}
  \item{initmethod}{Method of determining initial values for sampling. Options are "zero" for all zeros on fixed effects (except Intercepts) and ones on standard deviations, "random" for random inits within parameter support, and "lme4" for estimates from a \code{glmer} fit.}
  \item{extract}{If TRUE, extracts samples (minus warmup) from resulting \code{rstan} fit and returns only the samples, not the entire \code{stanfit} object}
  \item{calcDIC}{If TRUE, computes the Deviance Information Criterion, DIC, after sampling}
  \item{verbose}{If TRUE, displays various progress messages}
  \item{fixed_prefix}{Text to prepend to fixed effect parameter names. Default is 'beta_'.}
  \item{vary_prefix}{Text to prepend to varying effect parameter names. Default is 'vary_'.}
  \item{...}{additional parameters to pass to \code{\link{stan}}}
}
\details{
  This command uses the varying effects and fixed effects structures of a \code{\link{glmer}} model formula to define the corresponding model in \code{\link{rstan}}. There are two modes. 
  
  First, when option \code{sample=FALSE}, the command will define the model code and the \code{data} and \code{init} lists for \code{\link{stan}}, returning them in a list with named slots \code{model}, \code{data}, and \code{init}. These objects can later be passed to \code{\link{stan}} to sample from the model. You can use \code{show} to display the model code in a readable format.
  
  Second, when \code{sample=TRUE}, the \code{glmer2stan} will begin \code{rstan} sampling, returning the \code{stanfit} object. Once sampling is done, the functions \code{\link{stanmer}} and \code{\link{varef}} provide summary and varying effect estimates, respectively, for the \code{stanfit} object. Also, all of the summary, plotting, and display functions defined by \code{rstan} still operate normally.
 
  It is possible to pass lists of formulas and families. In that case, \code{glmer2stan} defines multiple outcome models that may share varying effects. Using lists in this way, it is possible to define mixture models, as well as multilevel MANOVA-style models. For example, the family \code{list('binomial','poisson')} corresponds to a zero-inflated poisson. Any varying effect grouping variables shared across formulas define large blocks of varying effects that bridge outcome variables.
  
  Note that \code{glmer2stan} does not yet correctly handle models that pair varying slopes with non-varying intercepts. For example, \code{y ~ (0+x|id) + x} indicates a model with varying slopes on \code{x}, but no varying intercepts. This is a legitimate (although unusual) model, and \code{glmer} will estimate it, but \code{glmer2stan} will not define it properly. A later release may fix this issue. For now, manually editing the model code is necessary.
  
  When \code{calcDIC=TRUE}, additional code is added to the model that computes the deviance at each sample. These can later be used to simplify computing DIC. When sampling is also done through \code{glmer2stan}, DIC will be computed and displayed when the chain completes. DIC is defined as \code{2*Dbar - Dhat}, where \code{Dbar} is the average deviance and \code{Dhat} is the deviance at the average values of all parameters. All samples after warmup are used to compute these averages.
  
  When choosing \code{family='ordered'}, the parameter vector \code{cutpoints} will contain the ordered intercepts. The outcome variable must be integer valued with minimum 1.
  
  Family \code{'gamma'} uses a log link on the mean of the gamma density. The rate (inverse scale) parameter for the gamma distribution is returned as \code{theta}. \code{glmer2stan} will try to guess a good initial value for \code{theta} by maximum likelihood search, but manual choice of inits may be necessary in some cases.
  
  Model families \code{'zigamma'} and \code{'zipoisson'} are special cases. These are shortcuts for defining two-formula zero-inflated gamma or zero-inflated poisson multilevel models. They are equivalent to passing two formulas and a list of families \code{list('binomial','gamma')} or \code{list('binomial','poisson')}. You can define these models using either a single formula with an outcome that is a mix of zeros and positive values or a list of two formulas. In the first case, a single formula, \code{glmer2stan} will automatically split the outcome into an indicator variable for zeros and another outcome containing positive values (gamma) or counts (poisson). Then it will duplicate the right hand side of the formula for both outcomes. In the second case, a list of two formulas, it uses the first to define a bernoulli (logit link) model for zero observations and the second to define either a gamma (log link) model for positive observations or a poisson (log link) model for all observed counts. In both cases, the formulas share any varying effect groups they have in common, allowing for correlations across the two models. 
  
  When using the default \code{initmethod} of \code{'zero'}, the code tries to guess good starting values for any Intercept parameters. All other fixed effects are initialized at zero. 
  
  When using \code{initmethod='lme4'} to initialize parameters, variance components may be initialized to defaults. This is necessary whenever \code{glmer} returns a boundary estimate: zero variance or -1/+1 correlation.
  
  The \code{varpriors='weak'} priors for variance components are \code{sigma ~ gamma(2,1e-4)} prior for standard deviations of varying effects and \code{Rho ~ lkj_corr(1.5)} prior for correlation structure of the multivariate effects. The \code{eta=1.5} value creates a nearly-uniform correlation prior, but with low prior probability for correlations near -1 and +1. Changing \code{eta} to 1 creates a uniform correlation prior. Estimates are still reported in a merged \code{Sigma} variance-covariance matrix, even though priors are defined separately for standard deviations and the correlation matrix. See the model code for details. The \code{varpriors='flat'} preset uses uniform priors. Stan does not need nor benefit from the use of fully conjugate priors, so they are not provided as a preset. However, any prior can of course be manually added to the model code, using option \code{sample=FALSE}.
  
  All top-level (fixed effect) regression parameters are assigned default \code{normal(0,100)} priors. To change these, set \code{sample=FALSE} and edit the model code directly.
}
\references{}
\author{Richard McElreath}
\seealso{\code{\link{glmer}},\code{\link{stan}}}
\examples{
# gaussian test

# simulate data
library(MASS)
N <- 1000 # 1000 cases
J <- 100 # 100 clusters
J2 <- 20
NperJ <- N/J
sigma <- 2 # top-level standard deviation
mu <- c(10,-0.5) # means of varying effects coefficients
x <- runif(N,min=-2,max=2) # predictor variable
x2 <- runif(N,min=-2,max=2)
id <- rep( 1:J , each=NperJ ) # cluster id's
id2 <- rep( 1:J2 , each=N/J2 )
Sigma <- matrix( 0 , nrow=2 , ncol=2 ) # var-cov matrix
Sigma[1,1] <- 2
Sigma[2,2] <- 0.2
Sigma[1,2] <- Sigma[2,1] <- -0.8 * sqrt( Sigma[1,1] * Sigma[2,2] )
beta <- mvrnorm( J , mu=mu , Sigma=Sigma )
y <- rnorm( N , mean=beta[id,1]+beta[id,2]*x , sd=sigma )

# display model code
model.code <- glmer2stan( y ~ (1+x+x2|id) + (1+x|id2) + x + x2 , 
  data=list(y=y,x=x,x2=x2,id=id,id2=id2) , family="gaussian" , 
  calcDIC=TRUE , sample=FALSE )
show(model.code)

# now fit rstan model
stanresult <- glmer2stan( y ~ (1+x+x2|id) + (1+x|id2) + x + x2 , 
  data=list(y=y,x=x,x2=x2,id=id,id2=id2) , family="gaussian" , 
  calcDIC=TRUE , sample=TRUE )

# summarize
stanmer(stanresult)
varef(stanresult)
}
% Add one or more standard keywords, see file 'KEYWORDS' in the
% R documentation directory.
\keyword{ }

