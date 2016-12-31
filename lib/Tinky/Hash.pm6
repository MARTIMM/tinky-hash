use v6.c;
use Tinky;
#use Data::Dump::Tree;

class Tinky::Hash does Tinky::Object {

  my Hash $states = {};
  my Hash $transitions = {};
  my Hash $workflow = {};
  my Hash $configs = {};
  my Str $current-wf = '';

  #-----------------------------------------------------------------------------
  submethod BUILD ( Hash :$config ) {

    self.from-hash(:$config) if $config.defined;
  }

  #-----------------------------------------------------------------------------
  method from-hash ( Hash:D :$config ) {

    self!init;
    self!check($config);

    # Setup all states
    for @($config<states>) -> $state {
      $states{$state} = Tinky::State.new(:name($state));
    }

    # Check and setup all transitions
    my Hash $trs = $config<transitions>;
    for $trs.keys -> $name {

      $transitions{$name} = Tinky::Transition.new(
        :$name,
        :from($states{$trs{$name}<from>}),
        :to($states{$trs{$name}<to>})
      );
    }

    # Check and setup workflow
    my Tinky::State $istate =
       $states{$config<workflow><initial-state>} // Tinky::State;

    $workflow{$config<workflow><name>} = Tinky::Workflow.new(
      :name($config<workflow><name>),
      :states($states.values),
      :transitions($transitions.values),
      :initial-state($istate)
    );

    $configs{$config<workflow><name>} = $config;
  }

  #-----------------------------------------------------------------------------
  method workflow ( Str:D $workflow-name ) {

    if ?$workflow{$workflow-name} {

      my Str $current-state = self.state.name if self.state.defined;
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

    $current-wf = $workflow-name;
    self!set-taps;
  }

  #-----------------------------------------------------------------------------
  method !set-taps ( ) {

    # check if already configured
    unless $configs{$current-wf}<taps><taps-set> {

      # setup the state taps
      my Hash $taps = $configs{$current-wf}<taps> // {};
      my Array $stcfg = $configs{$current-wf}<states> // [];
      
      # setup the state taps
      for $taps<states>.keys -> $sk {

        my Str $enter = $taps<states>{$sk}<enter> // Str;
        $states{$sk}.enter-supply.tap(
          -> $o { self."$enter"($o); }
        ) if ?$enter;

        my Str $leave = $taps<states>{$sk}<leave> // Str;
        $states{$sk}.leave-supply.tap(
          -> $o { self."$leave"($o); }
        ) if ?$leave;
      }


      # setup the transition taps
      my Hash $trcfg = $configs{$current-wf}<transitions> // {};
      my Str $global-method = $taps<transitions-global> // Str;

      # are there any taps to be made
      if $taps<transitions>.elems or ?$global-method {
        $workflow{$current-wf}.transition-supply.tap(
          -> ( $t, $o) {

            for $taps<transitions>.keys -> $tk {
              my $from = $trcfg{$tk}<from>;
              my $to = $trcfg{$tk}<to>;

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
      }

      # taps are now configured
      $configs{$current-wf}<taps><taps-set> = True;
    }
  }

  #-----------------------------------------------------------------------------
  method go-state ( Str:D $state-name ) {

    my Tinky::State $nstate = $states{$state-name} // Tinky::State;
    if ?$nstate {

      self.state = $nstate;
    }

    else {

      die "Next state '$state-name' not defined";
    }
  }

  #-----------------------------------------------------------------------------
  method !init ( ) {

    $states = {};
    $transitions = {};
  }

  #-----------------------------------------------------------------------------
  method !check ( $cfg ) {

    # check config
    die "No configuration provided" unless ?$cfg and $cfg.keys;

    # get states
    my @states = @($cfg<states>) // ();
    die "No states defined" unless +@states;

    # check states in transitions
    for $cfg<transitions>.keys -> $tk {
      my Str $s = $cfg<transitions>{$tk}<from>;
      die "From-state in transition $tk is not defined" unless ?$s;
      die "From-state '$s' not defined in states in transition '$tk'"
        unless $s ~~ any(@states);

      $s = $cfg<transitions>{$tk}<to>;
      die "To-state in transition $tk is not defined" unless ?$s;
      die "To-state '$s' not defined in states in transition '$tk'"
        unless $s ~~ any(@states);
    }

    # check state in workflow
    my Str $wf = $cfg<workflow><name> // Str;
    die "Workflow is not defined" unless ?$wf;

    my Str $is = $cfg<workflow><initial-state>;
    die "Initial state '$is' in workflow '$wf' is defined in states"
      unless $is ~~ any(@states);

    # check if workflow is used before
    die "Workflow '$wf' defined before" if $wf ~~ any($workflow.keys);

    # check global transition tap
    my Hash $taps = $cfg<taps> // Hash;
    if ?$taps {
      my Str $method = $taps<transitions-global> // Str;
      die "Global transition method '$method' not found in {self.^name()}"
        unless !$method or self.can($method);

      # check specific transition taps
      for $taps<transitions>.keys -> $tk {

        die "Transition name '$tk' not defined in transitions"
          unless $tk ~~ any($cfg<transitions>.keys);

        $method = $taps<transitions>{$tk} // Str;
        die "Specific transition method '$method' not found in {self.^name()}"
          unless !$method or self.can($method);
      }

      # check state taps
      for $taps<states>.keys -> $sk {

        die "State '$sk' in states tap not defined in states"
          unless $sk ~~ any(@states);

        $method = $taps<states>{$sk}<enter> // Str;
        die "State enter method not found in {self.^name()}"
          unless !$method or self.^can($method);

        $method = $taps<states>{$sk}<leave> // Str;
        die "State leave method not found in {self.^name()}"
          unless !$method or self.^can($method);
      }
    }
  }
}


