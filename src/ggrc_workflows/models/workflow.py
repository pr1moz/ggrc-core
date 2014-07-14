# Copyright (C) 2013 Google Inc., authors, and contributors <see AUTHORS file>
# Licensed under http://www.apache.org/licenses/LICENSE-2.0 <see LICENSE file>
# Created By: dan@reciprocitylabs.com
# Maintained By: dan@reciprocitylabs.com


from ggrc import db
from ggrc.models.associationproxy import association_proxy
from ggrc.models.mixins import (
    deferred, Base, Titled, Slugged, Described, Timeboxed
    )
from ggrc.models.reflection import PublishOnly
from ggrc.models.object_owner import Ownable
from sqlalchemy.orm import validates
from ggrc.models.computed_property import computed_property
from .task_group_object import TaskGroupObject
from .cycle_task_group_object import CycleTaskGroupObject
from .cycle import Cycle
from collections import OrderedDict
from datetime import date


class Workflow(Ownable, Timeboxed, Described, Titled, Slugged, Base, db.Model):
  __tablename__ = 'workflows'

  #Use these states for WorkflowCycle when it is implemented
  #VALID_STATES = [u"Planned", u"Future", u"In Progress", u"Overdue", u"Finished"]

  VALID_FREQUENCIES = ["one_time", "weekly", "monthly", "quarterly", "annually", "continuous"]

  @classmethod
  def default_frequency(cls):
    return 'continuous'

  @validates('frequency')
  def validate_frequency(self, key, value):
    if value is None:
      value = self.default_frequency()
    if value not in self.VALID_FREQUENCIES:
      message = u"Invalid state '{}'".format(value)
      raise ValueError(message)
    return value

  frequency = deferred(
    db.Column(db.String, nullable=True, default=default_frequency),
    'Workflow'
    )

  workflow_objects = db.relationship(
      'WorkflowObject', backref='workflow', cascade='all, delete-orphan')
  objects = association_proxy(
      'workflow_objects', 'object', 'WorkflowObject')

  workflow_people = db.relationship(
      'WorkflowPerson', backref='workflow', cascade='all, delete-orphan')
  people = association_proxy(
      'workflow_people', 'person', 'WorkflowPerson')

  workflow_tasks = db.relationship(
      'WorkflowTask', backref='workflow', cascade='all, delete-orphan')
  tasks = association_proxy(
      'workflow_tasks', 'task', 'WorkflowTask')

  task_groups = db.relationship(
      'TaskGroup', backref='workflow', cascade='all, delete-orphan')

  cycles = db.relationship(
      'Cycle', backref='workflow', cascade='all, delete-orphan')

  @computed_property
  def workflow_state(self):
    cycles = db.session.query(Cycle)\
      .filter(
        Cycle.workflow_id == self.id
      )\
      .all()

    return WorkflowState.get_state(cycles)

  _fulltext_attrs = []

  _publish_attrs = [
      'workflow_objects',
      PublishOnly('workflow_state'),
      PublishOnly('objects'),
      'workflow_people',
      PublishOnly('people'),
      'workflow_tasks',
      PublishOnly('tasks'),
      'task_groups',
      'frequency',
      'cycles',
      ]
  _stub_attrs = ['workflow_state']


class WorkflowState(object):

  _publish_attrs = [PublishOnly('workflow_state')]
  _update_attrs = []
  _stub_attrs = ['workflow_state']

  @classmethod
  def get_state(cls, objs):
    priority_states = OrderedDict([
      # The first True state will be returned
      ("Overdue", False),
      ("InProgress", False),
      ("Finished", False),
      ("Assigned", False),
      ("Verified", False)
    ])

    for obj in objs:
      today = date.today()
      if obj.end_date and \
         obj.end_date <= today and \
         obj.status != "Verified":
        priority_states["Overdue"] = True
      elif not obj.status:
        priority_states["Assigned"] = True
      priority_states[obj.status] = True

    for state in priority_states.keys():
      if priority_states[state]:
        return state

    return None

  @computed_property
  def workflow_state(self):

    cycle_objects = db.session.query(CycleTaskGroupObject)\
      .join(TaskGroupObject)\
      .filter(
        TaskGroupObject.object_id == self.id,
        TaskGroupObject.object_type == self.type,
        TaskGroupObject.id == CycleTaskGroupObject.task_group_object_id
      )\
      .all()

    return WorkflowState.get_state(cycle_objects)

# TODO: This makes the Workflow module dependant on Gdrive. It is not pretty.
from ggrc_gdrive_integration.models.object_folder import Folderable
Workflow.__bases__ = (Folderable,) + Workflow.__bases__
Workflow.late_init_folderable()