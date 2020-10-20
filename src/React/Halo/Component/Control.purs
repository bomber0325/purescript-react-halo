module React.Halo.Component.Control where

import Prelude
import Control.Applicative.Free (FreeAp, hoistFreeAp)
import Control.Monad.Free (Free, hoistFree, liftF)
import Control.Monad.State (class MonadState)
import Control.Monad.Trans.Class (class MonadTrans, lift)
import Data.Bifunctor (lmap)
import Data.Newtype (class Newtype, over)
import Data.Tuple (Tuple)
import Effect.Aff.Class (class MonadAff, liftAff)
import Effect.Class (class MonadEffect, liftEffect)
import Wire.Event (Event)

data HaloF props state action m a
  = Props (props -> a)
  | State (state -> Tuple a state)
  | Subscribe (SubscriptionId -> Event action) (SubscriptionId -> a)
  | Unsubscribe SubscriptionId a
  | Lift (m a)
  | Par (HaloAp props state action m a)
  | Fork (HaloM props state action m Unit) (ForkId -> a)
  | Kill ForkId a

newtype HaloM props state action m a
  = HaloM (Free (HaloF props state action m) a)

instance functorHaloF :: Functor m => Functor (HaloF props state action m) where
  map f = case _ of
    Props k -> Props (f <<< k)
    State k -> State (lmap f <<< k)
    Subscribe fes k -> Subscribe fes (map f k)
    Unsubscribe sid a -> Unsubscribe sid (f a)
    Lift m -> Lift (map f m)
    Par par -> Par (map f par)
    Fork fork k -> Fork fork (map f k)
    Kill fid a -> Kill fid (f a)

derive newtype instance functorHaloM :: Functor (HaloM props state action m)

derive newtype instance applyHaloM :: Apply (HaloM props state action m)

derive newtype instance applicativeHaloM :: Applicative (HaloM props state action m)

derive newtype instance bindHaloM :: Bind (HaloM props state action m)

derive newtype instance monadHaloM :: Monad (HaloM props state action m)

instance monadTransHaloM :: MonadTrans (HaloM props state action) where
  lift = HaloM <<< liftF <<< Lift

instance monadEffectHaloM :: MonadEffect m => MonadEffect (HaloM props state action m) where
  liftEffect = lift <<< liftEffect

instance monadAffHaloM :: MonadAff m => MonadAff (HaloM props state action m) where
  liftAff = lift <<< liftAff

instance monadStateHaloM :: MonadState state (HaloM props state action m) where
  state = HaloM <<< liftF <<< State

newtype HaloAp props state action m a
  = HaloAp (FreeAp (HaloM props state action m) a)

derive instance newtypeHaloAp :: Newtype (HaloAp props state action m a) _

derive newtype instance functorHaloAp :: Functor (HaloAp props state action m)

derive newtype instance applyHaloAp :: Apply (HaloAp props state action m)

derive newtype instance applicativeHaloAp :: Applicative (HaloAp props state action m)

newtype SubscriptionId
  = SubscriptionId Int

derive newtype instance eqSubscriptionId :: Eq SubscriptionId

derive newtype instance ordSubscriptionId :: Ord SubscriptionId

newtype ForkId
  = ForkId Int

derive newtype instance eqForkId :: Eq ForkId

derive newtype instance ordForkId :: Ord ForkId

hoist :: forall props state action m m'. Functor m => (m ~> m') -> HaloM props state action m ~> HaloM props state action m'
hoist nat (HaloM component) = HaloM (hoistFree go component)
  where
  go :: HaloF props state action m ~> HaloF props state action m'
  go = case _ of
    Props k -> Props k
    State k -> State k
    Subscribe event k -> Subscribe event k
    Unsubscribe sid a -> Unsubscribe sid a
    Lift m -> Lift (nat m)
    Par par -> Par (over HaloAp (hoistFreeAp (hoist nat)) par)
    Fork fork k -> Fork (hoist nat fork) k
    Kill fid a -> Kill fid a