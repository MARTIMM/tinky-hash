use v6.c;
use Tinky;
use Data::Dump::Tree;

class Tinky::Hash does Tinky::Object {

  has Hash $!states = {};
  has Hash $!transitions = {};
  my Hash $workflow = {};
  my Hash $configs = {};
  has Str $!current-wf = '';

  #-----------------------------------------------------------------------------
  submethod BUILD ( Hash :$config ) {

    self.from-hash(:$config) if $config.defined;
  }

  #-----------------------------------------------------------------------------
  method from-hash ( Hash:D :$config ) {

#dump $config;

    self!init;

    # Setup all states
    for @($config<states>) -> $state {
#say "S: $state";
      if $state ~~ Str {
        $!states{$state} = Tinky::State.new(:name($state));
      }

      elsif $state ~~ Hash {

        my Str $name = $state<name> // Str;
        if ?$name {
          $!states{$name} = Tinky::State.new(:$name);
        }

        else {
          die "No field :name for state defined";
        }

        my Str $method = $state<enter> // Str;
        $!states{$name}.enter-supply.act(
          -> $object { self."$method"(|$object); }
        ) if ?$method and self.^can($method);

        $method = $state<leave> // Str;
        $!states{$name}.leave-supply.act(
          -> $object { self."$method"(|$object); }
        ) if ?$method and self.^can($method);

        my Str $leave = $state<leave> // Str;
      }
    }

    # Check and setup all transitions
    my Hash $trs = $config<transitions>;
    for $trs.keys -> $name {
#say "T: $name $trs{$name}<from to>";
      my Tinky::State $from = $!states{$trs{$name}<from>} // Tinky::State;
      my Tinky::State $to = $!states{$trs{$name}<to>} // Tinky::State;

      if ?$from and ?$to {

        $!transitions{$name} = Tinky::Transition.new( :$name, :$from, :$to);
      }

      else {

        die "In transition '$name', one or both of 'from' and 'to' is not a defined state";
      }
    }

    # Check and setup workflow
    my Tinky::State $istate =
       $!states{$config<workflow><initial-state>} // Tinky::State;
    if ?$istate {

      $workflow{$config<workflow><name>} = Tinky::Workflow.new(
        :name($config<workflow><name>),
        :states($!states.values),
        :transitions($!transitions.values),
        :initial-state($istate)
      );

      $configs{$config<workflow><name>} = $config;
    }

    else {

      die "Initial state '$config<workflow><initial-state>' is not a defined state";
    }
  }

  #-----------------------------------------------------------------------------
  method workflow ( Str:D $workflow-name ) {

#say "WF $workflow-name";
#dump $configs{$workflow-name}<states>;
    if ?$workflow{$workflow-name} {

      my Str $current-state = self.state.name if self.state.defined;
#say "CS $current-state" if $current-state;
      if !$current-state or $current-state ~~ any(@($configs{$workflow-name}<states>)) {
        self.apply-workflow($workflow{$workflow-name});
      }

      else {
        die "State '$current-state' not found in workflow '$workflow-name'";
      }
    }

    else {
      die "Workflow name '$workflow-name' not defined";
    }

    $!current-wf = $workflow-name;
    self!set-taps;
  }

  #-----------------------------------------------------------------------------
  method !set-taps ( ) {

    unless $configs{$!current-wf}<taps><taps-set> {
#dump $configs{$!current-wf};
      my Hash $trcfg = $configs{$!current-wf}<transitions> // {};
      my Hash $taps = $configs{$!current-wf}<taps> // {};
      my Str $global-method = $taps<transitions-global> // Str;

      $workflow{$!current-wf}.transition-supply.tap(
        -> ( $t, $o) {

          for $taps<transitions>.keys -> $tk {
            my $from = $trcfg{$tk}<from>;
            my $to = $trcfg{$tk}<to>;
say "TM: $tk, $t.from.name(), $t.to.name(), $from, $to";

            my Str $spec-method = $taps<transitions>{$tk};
            self."$spec-method"( $t, $o)
                  if ?$spec-method and self.^can($spec-method)
                     and $t.from.name eq $from
                     and $t.to.name eq $to;
          }

          self."$global-method"( $t, $o)
                  if ?$global-method and self.^can($global-method);
        }
      );

      $configs{$!current-wf}<taps><taps-set> = True;
dump $configs{$!current-wf};
    }
  }

  #-----------------------------------------------------------------------------
  method go-state ( Str:D $state-name ) {

    my Tinky::State $nstate = $!states{$state-name} // Tinky::State;
    if ?$nstate {

      self.state = $nstate;
    }

    else {

      die "Next state '$state-name' not defined";
    }
  }

  #-----------------------------------------------------------------------------
  method !init ( ) {

    $!states = {};
    $!transitions = {};
#    $workflow = {};
  }
}


